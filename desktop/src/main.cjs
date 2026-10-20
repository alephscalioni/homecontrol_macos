const { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain, safeStorage, protocol, shell, screen } = require('electron');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { pathToFileURL } = require('node:url');
const { HAClient, normalizeServer } = require('./ha.cjs');
const M = require('./model.cjs');
const { demoHome } = require('./demo.cjs');
const { CredentialStore, configureBackend } = require('./credentials.cjs');
const { activationPoint, popupBounds, rectValid } = require('./popup.cjs');
const smoke = process.argv.includes('--smoke-test');
// The Linux desktop entry passes --ozone-platform=x11 before Electron starts,
// matching LedLinux's Qt/XCB popup positioning under XWayland.
if (process.platform === 'linux') {
  // This compact panel does not need a GPU; avoid host Mesa/Vulkan driver failures.
  app.disableHardwareAcceleration();
}
if (smoke) app.setPath('userData', require('node:fs').mkdtempSync(path.join(os.tmpdir(), 'homecontrol-smoke-')));
const credentialStore = new CredentialStore(path.join(app.getPath('userData'), 'connection.enc'), safeStorage);
configureBackend(app, credentialStore.file);
protocol.registerSchemesAsPrivileged([{ scheme: 'homecontrol', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } }]);
const panelURL = pathToFileURL(path.join(__dirname, 'index.html')).href;
const cameraURL = pathToFileURL(path.join(__dirname, 'camera.html')).href;
const client = new HAClient();
const cameras = new Map(); const mediaRequests = new Set(); const pending = new Set();
let panel, tray, quitting = false, demo = false, config = { profiles: {} }, credentials = null, status = '', saving = false, connecting = false;
let reconnectTimer, reconnectAttempt = 0, publishTimer, sessionGeneration = 0;
let remembered = false, restoringCredentials = false, lastLinuxAnchor = null;
const locale = () => app.getLocale().toLowerCase().startsWith('pt') ? 'pt-BR' : 'en-US';
const tr = (pt, en) => locale() === 'pt-BR' ? pt : en;
const prefsPath = () => path.join(app.getPath('userData'), 'preferences.json');
const account = () => demo ? 'demo' : credentials ? crypto.createHash('sha256').update(credentials.server + '\0' + credentials.token).digest('hex') : 'none';
const prefs = () => config.profiles[account()] ||= { favorites: [], hidden: [] };
async function writePrivate(file, text) {
  await fs.mkdir(path.dirname(file), { recursive: true, mode: 0o700 });
  await fs.writeFile(file + '.tmp', text, { mode: 0o600 }); await fs.rename(file + '.tmp', file);
}
async function savePreferences() { await writePrivate(prefsPath(), JSON.stringify(config)); }
function entities() { return [...client.entities.values()]; }
function snapshot() {
  const all = entities(); const registry = client.registry;
  const visibleEntries = registry.entities.filter(e => !e.hidden_by && !e.disabled_by);
  const entryMap = new Map(visibleEntries.map(e => [e.entity_id, e]));
  const registered = new Map(registry.entities.map(e => [e.entity_id, e]));
  const devices = new Map(registry.devices.map(d => [d.id, d]));
  const areas = new Map(registry.areas.map(a => [a.area_id, a.name]));
  const candidates = all.filter(e => M.supported(e) && (!registered.has(e.entity_id) || entryMap.has(e.entity_id)));
  const candidateIDs = new Set(candidates.map(e => e.entity_id));
  const owners = M.vacuumOwners(all, registry);
  const display = candidates.filter(e => {
    const owner = owners.get(e.entity_id);
    return !owner || !candidateIDs.has(owner) || prefs().hidden.includes(owner);
  }).map(e => {
    const entry = entryMap.get(e.entity_id); const area = entry?.area_id ?? devices.get(entry?.device_id)?.area_id;
    const value = { ...M.publicEntity(e), area_id: areas.has(area) ? area : null, category: entry?.entity_category || null };
    if (M.domain(e) === 'vacuum') {
      value.roomMap = M.roomMap(e, all, registry);
      value.related = M.related(e, all, registry)
        .filter(x => ['select', 'number', 'switch', 'sensor', 'binary_sensor'].includes(M.domain(x)) || (M.domain(x) === 'button' && M.dockKeys.some(k => x.entity_id.includes(k))))
        .map(x => ({ ...M.publicEntity(x), vacuum_section: M.vacuumSection(x, entryMap.get(x.entity_id)) }));
    }
    return value;
  });
  return { entities: display, areas: registry.areas.map(a => ({ id: a.area_id, name: a.name })), connected: client.connected, connecting: connecting || restoringCredentials, remembered, demo, status, registryWarning: client.registryWarning, saved: saving, server: credentials?.server || config.server || '', favorites: prefs().favorites, hidden: prefs().hidden, pending: [...pending], locale: locale(), version: app.getVersion() };
}
function publish() {
  clearTimeout(publishTimer);
  publishTimer = setTimeout(() => { if (panel && !panel.isDestroyed()) panel.webContents.send('home:changed', snapshot()); }, 35);
}
client.on('change', publish);
client.on('offline', error => {
  if (!credentials || demo) return;
  status = error.message; closeCameras(); publish();
  clearTimeout(reconnectTimer);
  reconnectTimer = setTimeout(reconnect, Math.min(30000, 1500 * 2 ** Math.min(reconnectAttempt++, 5)));
});
async function reconnect() {
  if (!credentials || demo || connecting) return;
  const current = sessionGeneration; connecting = true; publish();
  try { await client.connect(credentials.server, credentials.token); if (current === sessionGeneration) { reconnectAttempt = 0; status = ''; } }
  catch (error) { if (current === sessionGeneration) { status = error.message; reconnectTimer = setTimeout(reconnect, 5000); } }
  finally { if (current === sessionGeneration) { connecting = false; publish(); } }
}
async function restoreConnection() {
  if (!remembered || restoringCredentials || connecting || demo) return;
  const current = sessionGeneration;
  restoringCredentials = true; publish();
  try {
    const saved = await credentialStore.load();
    if (current !== sessionGeneration) return;
    credentials = { server: normalizeServer(saved.server), token: saved.token }; saving = true;
    await reconnect();
  } catch {
    if (current === sessionGeneration) {
      status = tr('Não foi possível abrir sua conexão salva. Desbloqueie o cofre do sistema e tente reconectar.', 'Your saved connection could not be opened. Unlock the system keyring and reconnect.');
      showPanel();
    }
  } finally { restoringCredentials = false; publish(); }
}
function closeCameras() {
  for (const controller of mediaRequests) controller.abort(); mediaRequests.clear();
  for (const window of cameras.values()) if (!window.isDestroyed()) window.close(); cameras.clear();
}
function resetSession() {
  sessionGeneration++; clearTimeout(reconnectTimer); closeCameras(); client.disconnect(); pending.clear();
  client.entities.clear(); client.registry = { areas: [], devices: [], entities: [] };
  client.registryWarning = false; connecting = false; demo = false; credentials = null; status = ''; saving = false;
}
async function connect({ server, token }) {
  if (connecting || restoringCredentials) throw new Error('Aguarde a conexão atual.');
  server = normalizeServer(server);
  if (typeof token !== 'string' || token.length > 16384 || !token.trim()) throw new Error('Informe o token de acesso.');
  resetSession(); const current = sessionGeneration; credentials = { server, token }; connecting = true; publish();
  try {
    await client.connect(server, token);
    if (current !== sessionGeneration) return;
    config.server = server; await savePreferences();
    if (current !== sessionGeneration) return;
    if (!smoke) {
      const stored = await credentialStore.save(credentials);
      if (current !== sessionGeneration) return;
      saving = stored;
      // A successful session without a keyring must not restore an older account.
      if (!saving) await credentialStore.clear();
      if (current !== sessionGeneration) return;
      remembered = saving;
    }
    reconnectAttempt = 0; status = '';
  } catch (error) {
    if (current === sessionGeneration) { resetSession(); status = error.message; }
    throw error;
  } finally { if (current === sessionGeneration) connecting = false; publish(); }
}
function activateDemo() {
  resetSession(); demo = true;
  const data = demoHome(); client.entities = new Map(data.entities.map(e => [e.entity_id, e])); client.registry = data.registry;
  client.connected = true; publish(); return snapshot();
}
function showPanel(activation = null) {
  if (!panel) return;
  let linuxPlacement;
  if (tray && process.platform === 'win32') {
    const bounds = tray.getBounds(); const display = screen.getDisplayNearestPoint({ x: bounds.x, y: bounds.y });
    const area = display.workArea; const [width, height] = panel.getSize();
    panel.setPosition(Math.max(area.x, Math.min(bounds.x + bounds.width - width, area.x + area.width - width)), Math.max(area.y, Math.min(bounds.y - height, area.y + area.height - height)));
  } else if (tray && process.platform === 'linux') {
    // Linux SNI does not implement Tray.getBounds(). Use activation coordinates,
    // with cursor/previous-anchor fallbacks, instead of leaving a centered window.
    const cursor = screen.getCursorScreenPoint();
    const point = activation?.fromTray ? activationPoint(activation.position, cursor, screen.getAllDisplays()) : lastLinuxAnchor;
    if (activation?.fromTray) lastLinuxAnchor = point;
    const display = screen.getDisplayNearestPoint(point || cursor);
    linuxPlacement = popupBounds(display, { width: 456, height: 696 }, point, rectValid(activation?.bounds) ? activation.bounds : null);
    panel.setMinimumSize(Math.min(400, linuxPlacement.width), Math.min(560, linuxPlacement.height));
    panel.setBounds(linuxPlacement);
    panel.setAlwaysOnTop(true, 'pop-up-menu');
  }
  panel.show();
  // Reassert after mapping so KWin's initial window-placement policy cannot center it.
  if (linuxPlacement) panel.setBounds(linuxPlacement);
  panel.focus(); publish();
}
function secureWindow(options) {
  const window = new BrowserWindow({ backgroundColor: '#0c0d0c', icon: path.join(__dirname, '../assets/icon.png'), autoHideMenuBar: true, ...options, webPreferences: { preload: path.join(__dirname, 'preload.cjs'), nodeIntegration: false, contextIsolation: true, sandbox: true, webSecurity: true } });
  window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  window.webContents.on('will-navigate', event => event.preventDefault());
  window.webContents.session.setPermissionRequestHandler((_wc, _permission, callback) => callback(false));
  return window;
}
function checkSender(event, cameraAllowed = false) {
  const window = BrowserWindow.fromWebContents(event.sender);
  const url = event.senderFrame?.url?.split('?')[0];
  if (event.senderFrame !== event.sender.mainFrame || !window || !((window === panel && url === panelURL) || (cameraAllowed && [...cameras.values()].includes(window) && url === cameraURL))) throw new Error('Origem inválida.');
  return window;
}
function handle(name, fn, cameraAllowed = false) {
  ipcMain.handle(name, async (event, ...args) => {
    try { const window = checkSender(event, cameraAllowed); return { ok: true, value: await fn(window, ...args) }; }
    catch (error) { return { ok: false, error: error.message || 'Não foi possível concluir a ação.' }; }
  });
}
function installIPC() {
  handle('home:get', () => snapshot());
  handle('home:connect', (_window, input) => connect(input));
  handle('home:demo', () => activateDemo());
  handle('home:forget', async () => { resetSession(); remembered = false; delete config.server; await credentialStore.clear(); await savePreferences(); publish(); return snapshot(); });
  handle('home:reconnect', () => credentials ? reconnect() : restoreConnection());
  handle('home:preference', async (_window, kind, id) => {
    if (!['favorites', 'hidden'].includes(kind) || !entities().some(e => e.entity_id === id && M.supported(e))) throw new Error('Aparelho inválido.');
    const values = prefs()[kind]; const index = values.indexOf(id); if (index === -1) values.push(id); else values.splice(index, 1);
    await savePreferences(); publish(); return snapshot();
  });
  handle('home:command', async (_window, input) => {
    if (!input || typeof input.id !== 'string' || typeof input.verb !== 'string' || !client.connected) throw new Error('Conecte ao Home Assistant antes de controlar um aparelho.');
    const entity = client.entities.get(input.id); if (!entity) throw new Error('Este aparelho foi removido.');
    const key = input.vacuumID || input.id;
    if (pending.has(key)) throw new Error('Aguarde a ação anterior.');
    const payload = M.command(entity, input.verb, input.value, { vacuumID: input.vacuumID, entities: entities(), registry: client.registry });
    pending.add(key); publish();
    try {
      if (demo) {
        const a = entity.attributes; const data = payload.service_data; const service = payload.service;
        if (service === 'turn_on' || service === 'turn_off') entity.state = service === 'turn_on' ? 'on' : 'off';
        if (data.hvac_mode) entity.state = data.hvac_mode;
        Object.assign(a, Object.fromEntries(Object.entries(data).filter(([k]) => k !== 'hvac_mode')));
        if ('brightness_pct' in data) { a.brightness = Math.round(data.brightness_pct * 2.55); entity.state = 'on'; }
        if ('option' in data) entity.state = data.option;
        if ('value' in data) entity.state = String(data.value);
        if (service === 'start') entity.state = 'cleaning'; if (service === 'pause') entity.state = 'paused';
        if (service === 'return_to_base') entity.state = 'returning'; if (service === 'stop') entity.state = 'idle';
        if (service === 'set_cover_position') a.current_position = data.position;
        if (service === 'open_cover' || service === 'close_cover') entity.state = service === 'open_cover' ? 'open' : 'closed';
      } else await client.request(payload);
    } finally { pending.delete(key); publish(); }
  });
  handle('home:camera', (_window, id) => {
    const entity = client.entities.get(id);
    if (!client.connected || demo || !entity || M.domain(entity) !== 'camera' || !M.available(entity)) throw new Error('A câmera está indisponível.');
    const existing = cameras.get(id); if (existing && !existing.isDestroyed()) { existing.show(); existing.focus(); return; }
    const window = secureWindow({ width: 480, height: 310, minWidth: 300, minHeight: 200, frame: false, title: entity.attributes.friendly_name || id });
    cameras.set(id, window); window.loadFile(path.join(__dirname, 'camera.html'), { query: { id, name: entity.attributes.friendly_name || id, locale: locale() } });
    window.on('closed', () => { if (cameras.get(id) === window) cameras.delete(id); });
  });
  handle('home:window', (window, action) => {
    if (action === 'close') { if (window === panel) window.hide(); else window.close(); }
    else if (action === 'pin' && window !== panel) { window.setAlwaysOnTop(!window.isAlwaysOnTop()); return window.isAlwaysOnTop(); }
    else if (action === 'expand' && window !== panel) window.isMaximized() ? window.unmaximize() : window.maximize();
    else if (action === 'size' && window !== panel) { const width = window.getSize()[0]; const next = width < 500 ? 640 : width < 700 ? 960 : 480; window.setSize(next, Math.round(next * 9 / 16) + 40); }
  }, true);
  handle('home:updates', async () => {
    await shell.openExternal('https://github.com/alephscalioni/homecontrol_macos/releases/tag/desktop-v0.5.0');
  });
}
function installMedia() {
  protocol.handle('homecontrol', async request => {
    const url = new URL(request.url); const id = decodeURIComponent(url.pathname.slice(1));
    const entity = client.entities.get(id);
    if (url.hostname !== 'camera' || request.method !== 'GET' || demo || !credentials || !client.connected || !entity || M.domain(entity) !== 'camera' || !M.available(entity)) return new Response('Unavailable', { status: 404 });
    const controller = new AbortController(); mediaRequests.add(controller);
    const abort = () => controller.abort(); request.signal.addEventListener('abort', abort, { once: true });
    const timer = setTimeout(abort, 20000);
    const cleanup = () => { clearTimeout(timer); mediaRequests.delete(controller); request.signal.removeEventListener('abort', abort); };
    try {
      const live = url.searchParams.get('live') === '1';
      const endpoint = credentials.server + (live ? '/api/camera_proxy_stream/' : '/api/camera_proxy/') + encodeURIComponent(id);
      const result = await fetch(endpoint, { headers: { Authorization: 'Bearer ' + credentials.token }, redirect: 'error', signal: controller.signal });
      const type = result.headers.get('content-type') || '';
      if (!result.ok || !(type.startsWith('image/') || (live && type.startsWith('multipart/x-mixed-replace')))) { controller.abort(); cleanup(); return new Response('Camera unavailable', { status: 502 }); }
      const headers = { 'Content-Type': type, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' };
      if (live) {
        clearTimeout(timer); const reader = result.body.getReader();
        return new Response(new ReadableStream({
          async pull(stream) { try { const { done, value } = await reader.read(); if (done) { stream.close(); cleanup(); } else stream.enqueue(value); } catch { stream.error(new Error('Stream interrupted')); cleanup(); } },
          cancel() { controller.abort(); cleanup(); return reader.cancel(); }
        }), { headers });
      }
      const chunks = []; let length = 0;
      for await (const chunk of result.body) { length += chunk.length; if (length > 8 * 1024 * 1024) throw new Error('Image too large'); chunks.push(chunk); }
      cleanup(); return new Response(Buffer.concat(chunks), { headers });
    } catch { controller.abort(); cleanup(); return new Response('Camera unavailable', { status: 502 }); }
  });
}
async function runSmoke() {
  activateDemo(); await panel.webContents.executeJavaScript('window.__homecontrolReady');
  const result = await panel.webContents.executeJavaScript(`(async () => {
    await window.home.demo(); await new Promise(r => setTimeout(r, 150));
    document.querySelector('[data-tab="climate"]').click(); await new Promise(r => setTimeout(r, 100));
    return { title: document.title, climate: !!document.querySelector('.temperature'), tabs: document.querySelectorAll('[data-tab]').length, text: document.body.innerText.includes('Ar da sala'), overflow: document.documentElement.scrollWidth > innerWidth };
  })()`);
  const dir = process.env.HOMECONTROL_SMOKE_DIR || path.join(os.tmpdir(), 'homecontrol-desktop-smoke'); await fs.mkdir(dir, { recursive: true });
  const focusedKey = await panel.webContents.executeJavaScript(`(() => { const slider = document.querySelector('[data-verb="temperature"]'); slider.focus(); return slider.dataset.focusKey; })()`);
  for (let step = 0; step < 2; step++) {
    panel.webContents.sendInputEvent({type:'keyDown',keyCode:'Right'}); panel.webContents.sendInputEvent({type:'keyUp',keyCode:'Right'});
    await new Promise(resolve => setTimeout(resolve, 160));
  }
  result.keyboardDetails = await panel.webContents.executeJavaScript(`(async () => { const state = await window.home.get(); return {focus: document.activeElement.dataset.focusKey, expected: ${JSON.stringify(focusedKey)}, hasFocus: document.hasFocus(), temperature: state.entities.find(e => e.entity_id === 'climate.living_room').attributes.temperature}; })()`);
  result.keyboard = result.keyboardDetails.focus === focusedKey && result.keyboardDetails.temperature === 24;
  await fs.writeFile(path.join(dir, 'climate.png'), (await panel.webContents.capturePage()).toPNG());
  await panel.webContents.executeJavaScript(`document.querySelector('[data-tab="rooms"]').click()`);
  await new Promise(r => setTimeout(r, 120)); await fs.writeFile(path.join(dir, 'rooms.png'), (await panel.webContents.capturePage()).toPNG());
  result.tray = !tray.isDestroyed(); result.platform = process.platform; result.arch = process.arch;
  result.favorite = await panel.webContents.executeJavaScript(`(async () => { const s = await window.home.preference('favorites','light.living_room'); return s.favorites.includes('light.living_room'); })()`);
  await panel.webContents.executeJavaScript(`document.querySelector('[data-room="living"]').click(); document.querySelector('[data-detail="vacuum.robot"]').click();`);
  await new Promise(r => setTimeout(r, 100));
  await fs.writeFile(path.join(dir, 'vacuum.png'), (await panel.webContents.capturePage()).toPNG());
  if (process.env.HOMECONTROL_SMOKE_SERVER) {
    const server = normalizeServer(process.env.HOMECONTROL_SMOKE_SERVER);
    if (new URL(server).hostname !== '127.0.0.1') throw new Error('Smoke server must be loopback.');
    result.protocol = await panel.webContents.executeJavaScript(`(async () => {
      await window.home.connect({server: ${JSON.stringify(server)}, token:'fixture-token'});
      let s = await window.home.get();
      const connected = s.connected && !s.demo;
      const redacted = !JSON.stringify(s).includes('fixture-token') && !JSON.stringify(s).includes('camera-secret');
      await window.home.command({id:'light.fixture',verb:'power'});
      await new Promise(r => setTimeout(r, 100));
      s = await window.home.get();
      let rejected = false; try { await window.home.command({id:'sensor.fixture',verb:'power'}); } catch { rejected = true; }
      await window.home.camera('camera.fixture');
      return {connected,redacted,command: s.entities.find(e => e.entity_id === 'light.fixture').state === 'on',rejected};
    })()`);
    const camera = cameras.get('camera.fixture');
    await new Promise(r => setTimeout(r, 1000));
    result.protocol.camera = await camera.webContents.executeJavaScript(`document.querySelector('#stream').naturalWidth > 0`);
    result.protocol.cameraPinned = await camera.webContents.executeJavaScript(`window.home.window('pin')`);
    await fs.writeFile(path.join(dir, 'camera.png'), (await camera.webContents.capturePage()).toPNG());
    const cameraClosed = new Promise(resolve => camera.once('closed', resolve));
    resetSession(); await cameraClosed; result.protocol.cameraClosed = camera.isDestroyed();
    if (!Object.values(result.protocol).every(Boolean)) throw new Error('Protocol smoke failed: ' + JSON.stringify(result.protocol));
  }
  await fs.writeFile(path.join(dir, 'result.json'), JSON.stringify(result, null, 2));
  console.log('HOMECONTROL_SMOKE ' + JSON.stringify(result)); quitting = true; app.exit(result.climate && result.tabs === 3 && result.text && !result.overflow && result.tray && result.keyboard ? 0 : 1);
}
if (!app.requestSingleInstanceLock()) app.quit();
else {
  app.on('second-instance', () => showPanel());
  app.whenReady().then(async () => {
    try { const saved = JSON.parse(await fs.readFile(prefsPath(), 'utf8')); if (saved && typeof saved.profiles === 'object' && saved.profiles) config = saved; } catch {}
    installIPC(); installMedia();
    const linuxPanel = process.platform === 'linux';
    panel = secureWindow({ width: 456, height: 696, minWidth: 400, minHeight: 560, title: 'HomeControl', show: false, resizable: !linuxPanel, ...(linuxPanel ? { frame: false, skipTaskbar: true, type: 'toolbar' } : {}) });
    panel.on('close', event => { if (!quitting) { event.preventDefault(); panel.hide(); } });
    if (linuxPanel) panel.on('blur', () => setTimeout(() => {
      if (!panel.isDestroyed() && panel.isVisible() && !panel.isFocused()) panel.hide();
    }, 250));
    const icon = nativeImage.createFromPath(path.join(__dirname, '../assets/icon.png')).resize({ width: 32, height: 32 });
    tray = new Tray(icon); tray.setToolTip('HomeControl');
    tray.setContextMenu(Menu.buildFromTemplate([{ label: tr('Abrir HomeControl', 'Open HomeControl'), click: () => showPanel({ fromTray: true }) }, { type: 'separator' }, { label: tr('Sair', 'Quit'), click: () => { quitting = true; app.quit(); } }]));
    tray.on('click', (_event, bounds, position) => {
      // Mirror LedLinux: one tray activation opens the popup, the next closes it.
      panel.isVisible() ? panel.hide() : showPanel({ fromTray: true, bounds, position });
    });
    remembered = await credentialStore.exists();
    await panel.loadFile(path.join(__dirname, 'index.html'));
    if (process.platform !== 'linux' || !remembered) showPanel();
    if (smoke) { await runSmoke(); return; }
    await restoreConnection();
  }).catch(error => { console.error('HomeControl startup:', smoke ? error.stack : error.message); app.exit(1); });
}
app.on('window-all-closed', () => {});
app.on('before-quit', () => { quitting = true; resetSession(); tray?.destroy(); });
