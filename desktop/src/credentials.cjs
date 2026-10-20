const fs = require('node:fs');
const path = require('node:path');

const backendSwitches = Object.freeze({ kwallet: 'kwallet', kwallet5: 'kwallet5', kwallet6: 'kwallet6', gnome_libsecret: 'gnome-libsecret' });

function unpack(bytes) {
  // Earlier versions wrote the encrypted buffer directly.
  if (bytes[0] !== 123) return { ciphertext: bytes, backend: null, legacy: true };
  const data = JSON.parse(bytes.toString('utf8'));
  if (data.format !== 1 || typeof data.ciphertext !== 'string' || !/^[A-Za-z0-9+/]+={0,2}$/.test(data.ciphertext) || (data.backend !== null && !Object.hasOwn(backendSwitches, data.backend))) throw new Error('Invalid saved connection format.');
  return { ciphertext: Buffer.from(data.ciphertext, 'base64'), backend: data.backend, legacy: false };
}

function configureBackend(app, file, platform = process.platform) {
  if (platform !== 'linux') return;
  try {
    const saved = unpack(fs.readFileSync(file));
    const value = backendSwitches[saved.backend];
    // Select the same keyring before Electron initializes safeStorage, even when
    // launched without the desktop session's KDE/GNOME environment variables.
    if (value) app.commandLine.appendSwitch('password-store', value);
  } catch { /* Restoration will surface missing/invalid files after readiness. */ }
}

class CredentialStore {
  constructor(file, storage, platform = process.platform) {
    this.file = file; this.storage = storage; this.platform = platform;
    this.operations = Promise.resolve(); this.generation = 0;
  }
  enqueue(operation) {
    const result = this.operations.then(operation);
    this.operations = result.catch(() => {});
    return result;
  }
  available() {
    return this.storage.isEncryptionAvailable() && (this.platform !== 'linux' || Object.hasOwn(backendSwitches, this.storage.getSelectedStorageBackend()));
  }
  backend() { return this.platform === 'linux' ? this.storage.getSelectedStorageBackend() : null; }
  async exists() { return fs.promises.access(this.file).then(() => true, () => false); }
  async writeEnvelope(ciphertext, generation) {
    if (generation !== this.generation) return false;
    const data = JSON.stringify({ format: 1, backend: this.backend(), ciphertext: ciphertext.toString('base64') });
    await fs.promises.mkdir(path.dirname(this.file), { recursive: true, mode: 0o700 });
    await fs.promises.writeFile(this.file + '.tmp', data, { mode: 0o600 });
    await fs.promises.chmod(this.file + '.tmp', 0o600);
    if (generation !== this.generation) { await fs.promises.rm(this.file + '.tmp', { force: true }); return false; }
    await fs.promises.rename(this.file + '.tmp', this.file);
    return true;
  }
  load() {
    const generation = this.generation;
    return this.enqueue(async () => {
      const saved = unpack(await fs.promises.readFile(this.file));
      if (!this.available() || (saved.backend && saved.backend !== this.backend())) throw new Error('Saved connection keyring is unavailable.');
      const credentials = JSON.parse(this.storage.decryptString(saved.ciphertext));
      if (typeof credentials.server !== 'string' || typeof credentials.token !== 'string' || !credentials.token.trim() || credentials.token.length > 16384) throw new Error('Invalid saved connection.');
      // A migration write failure must not prevent using a successfully decrypted
      // legacy connection. Preserve its original ciphertext for the next launch.
      if (saved.legacy) { try { await this.writeEnvelope(saved.ciphertext, generation); } catch {} }
      return credentials;
    });
  }
  save(credentials) {
    const generation = this.generation;
    return this.enqueue(async () => {
      if (generation !== this.generation || !this.available()) return false;
      return this.writeEnvelope(this.storage.encryptString(JSON.stringify(credentials)), generation);
    });
  }
  clear() {
    this.generation++;
    return this.enqueue(async () => {
      await fs.promises.rm(this.file, { force: true });
      await fs.promises.rm(this.file + '.tmp', { force: true });
    });
  }
}

module.exports = { CredentialStore, configureBackend };
