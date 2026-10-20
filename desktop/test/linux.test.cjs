const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { CredentialStore, configureBackend } = require('../src/credentials.cjs');
const { activationPoint, popupBounds } = require('../src/popup.cjs');

async function fixture(t, backend = 'kwallet6') {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'homecontrol-credentials-test-'));
  t.after(() => fs.rm(directory, { recursive: true, force: true }));
  const storage = {
    selected: backend, unlocked: true,
    getSelectedStorageBackend() { return this.selected; },
    isEncryptionAvailable() { return this.unlocked; },
    encryptString(value) {
      const iv = crypto.randomBytes(12), key = crypto.createHash('sha256').update(this.selected).digest();
      const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
      const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
      return Buffer.concat([Buffer.from('v11'), iv, cipher.getAuthTag(), encrypted]);
    },
    decryptString(value) {
      const key = crypto.createHash('sha256').update(this.selected).digest();
      const cipher = crypto.createDecipheriv('aes-256-gcm', key, value.subarray(3, 15));
      cipher.setAuthTag(value.subarray(15, 31));
      return Buffer.concat([cipher.update(value.subarray(31)), cipher.final()]).toString('utf8');
    }
  };
  const file = path.join(directory, 'connection.enc');
  return { file, storage, store: new CredentialStore(file, storage, 'linux') };
}
const credentials = { server: 'https://ha.example.test', token: 'private-test-token-never-plaintext' };

test('saved credentials survive a new instance and pin the original Linux keyring before readiness', async t => {
  const { file, store, storage } = await fixture(t);
  assert.equal(await store.save(credentials), true);
  const bytes = await fs.readFile(file);
  assert.equal(bytes.includes(credentials.token), false);
  assert.equal((await fs.stat(file)).mode & 0o777, 0o600);
  const switches = [];
  configureBackend({ commandLine: { appendSwitch: (...args) => switches.push(args) } }, file, 'linux');
  assert.deepEqual(switches, [['password-store', 'kwallet6']]);
  assert.deepEqual(await new CredentialStore(file, storage, 'linux').load(), credentials);
});
test('a locked or different keyring preserves the saved connection for retry', async t => {
  const { file, store, storage } = await fixture(t);
  await store.save(credentials); const before = await fs.readFile(file);
  storage.unlocked = false;
  await assert.rejects(store.load(), /unavailable/);
  assert.equal(await store.save(credentials), false);
  storage.unlocked = true; storage.selected = 'gnome_libsecret';
  await assert.rejects(store.load(), /unavailable/);
  assert.deepEqual(await fs.readFile(file), before);
  storage.selected = 'kwallet6';
  assert.deepEqual(await store.load(), credentials);
});
test('legacy encrypted connections migrate without changing the saved token', async t => {
  const { file, store, storage } = await fixture(t);
  await fs.writeFile(file, storage.encryptString(JSON.stringify(credentials)), { mode: 0o600 });
  assert.deepEqual(await store.load(), credentials);
  const migrated = JSON.parse(await fs.readFile(file, 'utf8'));
  assert.equal(migrated.backend, 'kwallet6');
  assert.equal(migrated.format, 1);
  assert.deepEqual(await store.load(), credentials);
});
test('GNOME metadata uses the supported command-line backend name', async t => {
  const { file, store } = await fixture(t, 'gnome_libsecret');
  await store.save(credentials); const switches = [];
  configureBackend({ commandLine: { appendSwitch: (...args) => switches.push(args) } }, file, 'linux');
  assert.deepEqual(switches, [['password-store', 'gnome-libsecret']]);
});
test('forgetting during legacy restoration cannot recreate the encrypted file', async t => {
  const { file, store, storage } = await fixture(t);
  await fs.writeFile(file, storage.encryptString(JSON.stringify(credentials)), { mode: 0o600 });
  const decrypt = storage.decryptString.bind(storage); let clearing;
  storage.decryptString = bytes => { clearing = store.clear(); return decrypt(bytes); };
  await store.load(); await clearing;
  assert.equal(await store.exists(), false);
});
test('forgetting during a pending save cancels that save', async t => {
  const { store, storage } = await fixture(t);
  const encrypt = storage.encryptString.bind(storage); let clearing;
  storage.encryptString = value => { clearing = store.clear(); return encrypt(value); };
  assert.equal(await store.save(credentials), false);
  await clearing; assert.equal(await store.exists(), false);
});
test('a failed legacy migration still restores the decrypted connection', async t => {
  const { file, store, storage } = await fixture(t);
  const original = storage.encryptString(JSON.stringify(credentials));
  await fs.writeFile(file, original, { mode: 0o600 });
  await fs.mkdir(file + '.tmp');
  assert.deepEqual(await store.load(), credentials);
  assert.deepEqual(await fs.readFile(file), original);
});
test('basic_text cannot persist credentials and corrupt envelopes cannot select a backend', async t => {
  const { file, store } = await fixture(t, 'basic_text');
  assert.equal(await store.save(credentials), false);
  assert.equal(await store.exists(), false);
  await fs.writeFile(file, JSON.stringify({ format: 1, backend: 'basic', ciphertext: 'AAAA' }));
  configureBackend({ commandLine: { appendSwitch: () => assert.fail('unsafe backend selected') } }, file, 'linux');
  await assert.rejects(store.load(), /format/);
});

const fedora = { bounds: { x: 0, y: 0, width: 5120, height: 1440 }, workArea: { x: 0, y: 28, width: 5120, height: 1336 } };
const size = { width: 456, height: 696 };
test('a Linux SNI activation with empty icon bounds opens against the top panel', () => {
  const actual = popupBounds(fedora, size, { x: 4990, y: 14 }, { x: 0, y: 0, width: 0, height: 0 });
  assert.deepEqual(actual, { x: 4664, y: 32, ...size });
  assert.deepEqual(popupBounds(fedora, size, { x: 5110, y: 14 }), { x: 4664, y: 32, ...size });
});
test('bottom and side panels work on displays with negative origins', () => {
  const left = { bounds: { x: -1920, y: 0, width: 1920, height: 1080 }, workArea: { x: -1920, y: 0, width: 1920, height: 1036 } };
  assert.deepEqual(popupBounds(left, size, { x: -150, y: 1060 }), { x: -456, y: 336, ...size });
  const side = { bounds: { x: 0, y: 0, width: 1920, height: 1080 }, workArea: { x: 60, y: 0, width: 1860, height: 1080 } };
  assert.deepEqual(popupBounds(side, size, { x: 28, y: 600 }), { x: 64, y: 252, ...size });
});
test('launcher activation defaults to the top and small work areas contain the entire popup', () => {
  assert.deepEqual(popupBounds(fedora, size), { x: 4664, y: 32, ...size });
  const small = { bounds: { x: -320, y: -240, width: 320, height: 240 }, workArea: { x: -320, y: -212, width: 320, height: 212 } };
  assert.deepEqual(popupBounds(small, size, { x: -160, y: -100 }), { x: -320, y: -212, width: 320, height: 212 });
});
test('missing and out-of-display SNI coordinates fall back to the cursor', () => {
  const cursor = { x: 4800, y: 14 };
  assert.deepEqual(activationPoint({ x: 0, y: 0 }, cursor, [fedora]), cursor);
  assert.deepEqual(activationPoint({ x: 9000, y: 14 }, cursor, [fedora]), cursor);
  assert.deepEqual(activationPoint({ x: 4700, y: 14 }, cursor, [fedora]), { x: 4700, y: 14 });
});
