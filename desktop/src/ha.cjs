const { EventEmitter } = require('node:events');
const WebSocket = require('ws');

function normalizeServer(input) {
  let url;
  try { url = new URL(String(input).trim()); } catch { throw new Error('Informe um endereço HTTP ou HTTPS válido.'); }
  if (!['http:', 'https:'].includes(url.protocol) || !url.hostname || url.username || url.password || url.search || url.hash) {
    throw new Error('Use o endereço HTTP ou HTTPS do Home Assistant, sem senha ou parâmetros.');
  }
  return url.href.replace(/\/+$/, '');
}

class HAClient extends EventEmitter {
  constructor({ timeout = 12000 } = {}) {
    super(); this.timeout = timeout; this.generation = 0; this.pending = new Map();
    this.entities = new Map(); this.registry = { areas: [], devices: [], entities: [] };
    this.connected = false; this.registryWarning = false;
  }
  disconnect() {
    this.generation++; this.connected = false;
    clearInterval(this.heartbeat); clearInterval(this.reconcile); clearTimeout(this.registryTimer);
    const error = new Error('Conexão encerrada.');
    this.authReject?.(error); this.authReject = null;
    for (const { reject, timer } of this.pending.values()) { clearTimeout(timer); reject(error); }
    this.pending.clear(); this.socket?.terminate(); this.socket = null;
  }
  async connect(server, token) {
    this.disconnect(); const generation = this.generation;
    this.server = normalizeServer(server); this.nextID = 0; this.buffer = []; this.buffering = true;
    this.entities.clear(); this.versions = new Map();
    this.registry = { areas: [], devices: [], entities: [] }; this.registryWarning = false;
    if (typeof token !== 'string' || !token.trim() || /[\r\n\x00]/.test(token)) throw new Error('Informe um token de acesso válido.');
    const socketURL = new URL(this.server + '/api/websocket');
    socketURL.protocol = socketURL.protocol === 'https:' ? 'wss:' : 'ws:';
    const socket = new WebSocket(socketURL, { followRedirects: false, maxPayload: 16 * 1024 * 1024, handshakeTimeout: this.timeout });
    this.socket = socket;
    const active = () => generation === this.generation;
    const authenticated = new Promise((resolve, reject) => {
      let settled = false;
      const finish = (error) => {
        if (settled) return; settled = true; clearTimeout(timer); token = '';
        this.authReject = null; error ? reject(error) : resolve();
      };
      const timer = setTimeout(() => finish(new Error('O Home Assistant demorou para responder.')), this.timeout);
      this.authReject = finish;
      socket.on('message', bytes => {
        if (!active()) return;
        let message;
        try { message = JSON.parse(bytes.toString()); } catch { this.fail(new Error('Resposta inválida do Home Assistant.')); return; }
        if (message.type === 'auth_required') socket.send(JSON.stringify({ type: 'auth', access_token: token }));
        else if (message.type === 'auth_invalid') finish(new Error('Token recusado. Crie outro no perfil do Home Assistant.'));
        else if (message.type === 'auth_ok') finish();
        else if (message.type === 'result' || message.type === 'pong') {
          const request = this.pending.get(message.id);
          if (!request) return;
          this.pending.delete(message.id); clearTimeout(request.timer);
          if (message.type === 'pong' || message.success) request.resolve(message.result);
          else request.reject(new Error(message.error?.message || 'O Home Assistant recusou a ação.'));
        } else if (message.type === 'event') {
          const event = message.event;
          if (event?.event_type === 'state_changed') {
            const change = { id: event.data?.entity_id, state: event.data?.new_state, timestamp: event.data?.new_state?.last_updated || event.time_fired };
            if (this.buffering) this.buffer.push(change); else { this.apply(change); this.emit('change'); }
          } else if (event?.event_type?.endsWith('_registry_updated')) {
            clearTimeout(this.registryTimer);
            this.registryTimer = setTimeout(() => this.refreshRegistry().catch(() => {}), 250);
          }
        }
      });
      socket.on('error', () => { if (active()) { finish(new Error('Não foi possível conectar ao Home Assistant. Confira o endereço e a rede.')); this.fail(new Error('A conexão com o Home Assistant falhou.')); } });
      socket.on('close', () => { if (active()) { finish(new Error('O Home Assistant encerrou a conexão.')); this.fail(new Error('Conexão perdida. Tentando reconectar…')); } });
    });
    try {
      await authenticated;
      if (!active()) throw new Error('Conexão substituída.');
      await this.request({ type: 'subscribe_events', event_type: 'state_changed' });
      const states = await this.request({ type: 'get_states' });
      if (!Array.isArray(states)) throw new Error('Lista de aparelhos inválida.');
      for (const state of states) this.apply({ id: state.entity_id, state, timestamp: state.last_updated });
      for (const change of this.buffer) this.apply(change);
      this.buffer = []; this.buffering = false; this.connected = true;
      await this.refreshRegistry();
      for (const event_type of ['area_registry_updated', 'device_registry_updated', 'entity_registry_updated']) {
        await this.request({ type: 'subscribe_events', event_type }).catch(() => {});
      }
      if (!active()) throw new Error('Conexão substituída.');
      this.heartbeat = setInterval(() => this.request({ type: 'ping' }).catch(() => { if (active()) this.fail(new Error('Conexão perdida. Tentando reconectar…')); }), 25000);
      this.reconcile = setInterval(() => this.refreshRegistry().catch(() => {}), 60000);
      this.emit('change');
    } catch (error) { if (active()) this.disconnect(); throw error; }
  }
  apply({ id, state, timestamp }) {
    if (typeof id !== 'string') return;
    const date = Date.parse(timestamp);
    if (Number.isFinite(date)) {
      if (date < (this.versions.get(id) ?? -Infinity)) return;
      this.versions.set(id, date);
    }
    if (state && typeof state.state === 'string') this.entities.set(id, state); else this.entities.delete(id);
  }
  async refreshRegistry() {
    const generation = this.generation;
    try {
      const results = await Promise.all(['area', 'device', 'entity'].map(kind => this.request({ type: `config/${kind}_registry/list` })));
      if (generation !== this.generation) return;
      if (!results.every(Array.isArray)) throw new Error('Cadastro inválido.');
      this.registry = { areas: results[0], devices: results[1], entities: results[2] }; this.registryWarning = false;
    } catch { if (generation === this.generation) this.registryWarning = true; }
    if (generation === this.generation) this.emit('change');
  }
  request(payload) {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) return Promise.reject(new Error('Home Assistant desconectado.'));
    const id = ++this.nextID;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.pending.delete(id); reject(new Error('A ação demorou para responder. Confira o estado do aparelho antes de tentar novamente.')); }, this.timeout);
      this.pending.set(id, { resolve, reject, timer });
      this.socket.send(JSON.stringify({ ...payload, id }), error => {
        if (error) { const entry = this.pending.get(id); if (entry) { clearTimeout(entry.timer); this.pending.delete(id); entry.reject(new Error('Falha ao enviar a ação.')); } }
      });
    });
  }
  fail(error) { this.disconnect(); this.emit('offline', error); }
}
module.exports = { HAClient, normalizeServer };
