const { test } = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { WebSocketServer } = require('ws');
const { HAClient, normalizeServer } = require('../src/ha.cjs');
async function fixture(t, { auth = true, ignore = null, registryError = false, snapshotRace = false } = {}) {
  const server = new WebSocketServer({ port: 0, host: '127.0.0.1' });
  await once(server, 'listening'); const received = [];
  server.on('connection', socket => {
    socket.send(JSON.stringify({ type: 'auth_required' }));
    socket.on('message', bytes => {
      const message = JSON.parse(bytes.toString()); received.push(message);
      const send = value => socket.send(JSON.stringify(value));
      const response = result => send({ id: message.id, type: 'result', success: true, result });
      if (message.type === 'auth') { send({ type: message.access_token === 'fixture-token' && auth ? 'auth_ok' : 'auth_invalid' }); return; }
      if (message.type === ignore) return;
      if (message.type === 'ping') { send({ type: 'pong', id: message.id }); return; }
      if (message.type === 'subscribe_events' && message.event_type === 'state_changed' && snapshotRace) send({ type: 'event', event: { event_type: 'state_changed', data: { entity_id: 'light.test', new_state: { entity_id: 'light.test', state: 'on', attributes: {}, last_updated: '2026-10-19T12:00:02Z' } } } });
      if (message.type === 'get_states') response([{ entity_id: 'light.test', state: 'off', attributes: {}, last_updated: '2026-10-19T12:00:01Z' }]);
      else if (message.type.includes('_registry/list')) {
        if (registryError) send({ id: message.id, type: 'result', success: false, error: { message: 'permission denied' } });
        else response([]);
      } else response(null);
    });
  });
  const client = new HAClient({ timeout: 150 });
  t.after(async () => { client.disconnect(); for (const socket of server.clients) socket.terminate(); await new Promise(resolve => server.close(resolve)); });
  return { client, server, received, url: `http://127.0.0.1:${server.address().port}` };
}
test('normalizes server addresses and rejects embedded credentials and query strings', () => {
  assert.equal(normalizeServer(' https://ha.example/subpath/// '), 'https://ha.example/subpath');
  for (const url of ['ftp://ha.local','https://user:password@ha.local','https://ha.local/?token=secret','https://ha.local/#x','not-an-address']) assert.throws(() => normalizeServer(url));
});
test('subscribes before snapshot and preserves newer events during initial fetch', async t => {
  const { client, url, received } = await fixture(t, { snapshotRace: true });
  await client.connect(url, 'fixture-token');
  assert.equal(client.connected, true);
  assert.equal(client.entities.get('light.test').state, 'on');
  const types = received.map(m => m.type);
  assert.ok(types.indexOf('subscribe_events') < types.indexOf('get_states'));
  const ids = received.filter(m => m.id).map(m => m.id);
  assert.deepEqual(ids, [...ids].sort((a,b)=>a-b));
});
test('auth rejection clears the socket and does not expose the token in errors', async t => {
  const { client, url } = await fixture(t, { auth: false });
  await assert.rejects(client.connect(url, 'fixture-token'), error => !error.message.includes('fixture-token'));
  assert.equal(client.connected, false); assert.equal(client.socket, null);
});
test('request timeout rejects rather than reporting a successful command', async t => {
  const { client, url } = await fixture(t, { ignore: 'call_service' });
  await client.connect(url, 'fixture-token');
  await assert.rejects(client.request({ type: 'call_service' }), /demorou/);
  assert.equal(client.pending.size, 0);
});
test('registry permissions do not silently erase the connection or report empty-home success', async t => {
  const { client, url } = await fixture(t, { registryError: true });
  await client.connect(url, 'fixture-token');
  assert.equal(client.connected, true); assert.equal(client.registryWarning, true);
  assert.equal(client.entities.size, 1);
});
test('older updates cannot overwrite newer values and removal tombstones prevent resurrection', async t => {
  const { client, url } = await fixture(t);
  await client.connect(url, 'fixture-token');
  client.apply({ id: 'light.test', state: null, timestamp: '2026-10-19T12:00:03Z' });
  client.apply({ id: 'light.test', state: { entity_id: 'light.test', state: 'on' }, timestamp: '2026-10-19T12:00:02Z' });
  assert.equal(client.entities.has('light.test'), false);
});
test('disconnect rejects pending requests and cancels timers', async t => {
  const { client, url } = await fixture(t, { ignore: 'call_service' });
  await client.connect(url, 'fixture-token');
  const request = client.request({ type: 'call_service' }); client.disconnect();
  await assert.rejects(request, /encerrada/); assert.equal(client.pending.size, 0);
});
