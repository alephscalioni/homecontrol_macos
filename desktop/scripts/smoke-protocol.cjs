// End-to-end fixture: no real Home Assistant, device commands or credentials.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { WebSocketServer } = require('ws');
const image = fs.readFileSync(path.join(__dirname, '../assets/air-conditioner.png'));
const states = [
  { entity_id: 'light.fixture', state: 'off', attributes: { friendly_name: 'Fixture light' } },
  { entity_id: 'sensor.fixture', state: '23', attributes: { friendly_name: 'Fixture sensor', unit_of_measurement: '°C' } },
  { entity_id: 'camera.fixture', state: 'idle', attributes: { friendly_name: 'Fixture camera', access_token: 'camera-secret', entity_picture: '/image?token=camera-secret' } }
];
const server = http.createServer((request, response) => {
  if (request.headers.authorization !== 'Bearer fixture-token') { response.writeHead(401); response.end(); return; }
  if (request.url.startsWith('/api/camera_proxy_stream/')) {
    response.writeHead(200, { 'Content-Type': 'multipart/x-mixed-replace; boundary=frame', 'Cache-Control': 'no-store' });
    const send = () => { response.write('--frame\r\nContent-Type: image/png\r\nContent-Length: ' + image.length + '\r\n\r\n'); response.write(image); response.write('\r\n'); };
    send(); const timer = setInterval(send, 300); response.on('close', () => clearInterval(timer));
  } else if (request.url.startsWith('/api/camera_proxy/')) { response.writeHead(200, { 'Content-Type': 'image/png' }); response.end(image); }
  else { response.writeHead(404); response.end(); }
});
const ws = new WebSocketServer({ server, path: '/api/websocket' });
ws.on('connection', socket => {
  socket.send(JSON.stringify({ type: 'auth_required' }));
  socket.on('message', bytes => {
    const message = JSON.parse(bytes.toString());
    const send = value => socket.send(JSON.stringify(value));
    const result = value => send({ id: message.id, type: 'result', success: true, result: value });
    if (message.type === 'auth') { send({ type: message.access_token === 'fixture-token' ? 'auth_ok' : 'auth_invalid' }); return; }
    if (message.type === 'get_states') result(states);
    else if (message.type.includes('_registry/list')) result([]);
    else if (message.type === 'ping') send({ id: message.id, type: 'pong' });
    else if (message.type === 'call_service') {
      const state = states.find(x => x.entity_id === message.target.entity_id);
      state.state = message.service === 'turn_on' ? 'on' : 'off';
      result(null); send({ type: 'event', event: { event_type: 'state_changed', data: { entity_id: state.entity_id, new_state: state } } });
    } else result(null);
  });
});
server.listen(0, '127.0.0.1', () => {
  const child = spawn(require('electron'), ['.', '--smoke-test'], { cwd: path.join(__dirname, '..'), env: { ...process.env, HOMECONTROL_SMOKE_SERVER: 'http://127.0.0.1:' + server.address().port }, stdio: 'inherit' });
  const timeout = setTimeout(() => { child.kill(); console.error('Electron smoke timed out'); }, 45000);
  child.on('exit', code => { clearTimeout(timeout); for (const socket of ws.clients) socket.terminate(); server.closeAllConnections(); server.close(() => process.exit(code ?? 1)); });
});
