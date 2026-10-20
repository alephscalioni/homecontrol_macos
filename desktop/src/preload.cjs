const { contextBridge, ipcRenderer } = require('electron');
async function invoke(channel, ...args) {
  const response = await ipcRenderer.invoke(channel, ...args);
  if (!response.ok) throw new Error(response.error);
  return response.value;
}
contextBridge.exposeInMainWorld('home', {
  get: () => invoke('home:get'),
  connect: input => invoke('home:connect', input),
  demo: () => invoke('home:demo'),
  forget: () => invoke('home:forget'),
  reconnect: () => invoke('home:reconnect'),
  preference: (kind, id) => invoke('home:preference', kind, id),
  command: input => invoke('home:command', input),
  camera: id => invoke('home:camera', id),
  window: action => invoke('home:window', action),
  updates: () => invoke('home:updates'),
  changed: callback => { const listener = (_event, snapshot) => callback(snapshot); ipcRenderer.on('home:changed', listener); return () => ipcRenderer.removeListener('home:changed', listener); }
});
