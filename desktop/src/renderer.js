/* The renderer has no Node.js or direct network access. All commands pass through the host. */
const paths = {
  home:'m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1Z',
  wind:'M3 8h12a3 3 0 1 0-3-3M2 12h17a3 3 0 1 1-3 3M4 16h5a3 3 0 1 1-3 3',
  rooms:'M3 3h7v7H3ZM14 3h7v7h-7ZM3 14h7v7H3ZM14 14h7v7h-7Z',
  star:'m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9Z',
  settings:'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8ZM9 3l-1 3-3 1-2 3 2 3v3l3 2 1 3h6l1-3 3-2v-3l2-3-2-3-3-1-1-3Z',
  close:'m6 6 12 12M6 18 18 6', power:'M12 3v8M6.3 5.8a8 8 0 1 0 11.4 0',
  plus:'M12 5v14M5 12h14', minus:'M5 12h14', back:'m15 5-7 7 7 7', next:'m9 5 7 7-7 7',
  light:'M9 18h6M9 21h6M8 14a6 6 0 1 1 8 0l-1 3H9Z', switch:'M8 6h8a6 6 0 0 1 0 12H8A6 6 0 0 1 8 6ZM8 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z',
  fan:'M12 12c-5-2-7-8-3-9s6 4 3 9Zm0 0c4-4 10-3 9 1s-7 5-9-1Zm0 0c1 6-3 10-6 7s0-8 6-7Z',
  cover:'M4 3v18M20 3v18M4 4h16M4 8h16M4 12h16M4 16h16M4 20h16',
  scene:'m13 2-9 12h7l-1 8 10-12h-7Z', sensor:'M8 14V6a4 4 0 0 1 8 0v8a6 6 0 1 1-8 0ZM12 8v10',
  binary_sensor:'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18ZM12 8v5M12 16h.01',
  camera:'M3 7h12v10H3ZM15 10l6-3v10l-6-3Z', vacuum:'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18ZM7 8h10M10 16h4M12 11h.01',
  mode:'M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6 7 7M17 17l1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z',
  swing:'M4 6h16M4 10h16M7 14v6l-3-3M17 14v6l3-3', leaf:'M20 3C10 2 3 7 4 13s11 9 16-10ZM4 21l10-11',
  eye:'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12ZM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z',
  refresh:'M20 7v5h-5M4 17v-5h5M6 7a7 7 0 0 1 12-1l2 6M4 12l2 6a7 7 0 0 0 12-1',
  play:'m8 4 12 8-12 8Z', pause:'M8 4v16M16 4v16', stop:'M6 6h12v12H6Z',
  battery:'M3 7h16v10H3ZM22 10v4M6 10v4M9 10v4M12 10v4',
  pin:'m9 3 6 0-1 6 4 4v2H6v-2l4-4ZM12 15v7', expand:'M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5',
  water:'M12 3S5 11 5 15a7 7 0 0 0 14 0c0-4-7-12-7-12Z'
};
function icon(name) { return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${paths[name] || paths.home}"/></svg>`; }
const english = {
 'Sua conexão está salva.':'Your connection is saved.',
 'Vamos reconectar ao seu Home Assistant. Você não precisa informar o token novamente.':'We will reconnect to your Home Assistant. You do not need to enter your token again.',
 'Alterar conexão':'Change connection',
 'Ar-condicionado':'Climate','Cômodos':'Rooms','Favoritos':'Favorites','Configurações':'Settings','Fechar':'Close','Demonstração':'Demonstration','Conectar minha casa':'Connect my home','Conectado':'Connected','Desconectado':'Disconnected','Conectando…':'Connecting…','Reconectar':'Reconnect','Sua casa, mais perto.':'Your home, closer.','Controle seus aparelhos pelo painel do HomeControl. Conecte seu Home Assistant para começar.':'Control your devices from HomeControl. Connect your Home Assistant to get started.','Endereço do Home Assistant':'Home Assistant address','Token de acesso':'Access token','Mostrar token':'Show token','No Home Assistant: Perfil → Segurança → Tokens de acesso de longa duração.':'In Home Assistant: Profile → Security → Long-lived access tokens.','Conectar ao Home Assistant':'Connect to Home Assistant','Explorar demonstração':'Explore demonstration','Seu token fica neste computador. Quando o cofre do sistema está disponível, a conexão é salva de forma protegida.':'Your token stays on this computer. When the system credential store is available, your connection is saved securely.','Sem ar-condicionado':'No climate devices','Os aparelhos de clima conectados aparecerão aqui.':'Your connected climate devices will appear here.','Sem favoritos por enquanto':'No favorites yet','Marque a estrela de um aparelho para encontrá-lo aqui.':'Star a device to find it here.','Nenhum aparelho encontrado':'No devices found','Tente outro nome ou tipo de aparelho.':'Try another name or device type.','Sem cômodo':'Unassigned','Buscar aparelho ou cômodo':'Search devices or rooms','Voltar':'Back','Sem leitura':'No reading','Indisponível':'Unavailable','Ligado':'On','Desligado':'Off','Aberta':'Open','Fechada':'Closed','Na base':'Docked','Limpando':'Cleaning','Pausado':'Paused','Voltando à base':'Returning to dock','Em espera':'Idle','Resfriando':'Cooling','Aquecendo':'Heating','Desumidificando':'Drying','Ventilando':'Fan only','Carregando':'Charging','Temperatura atual':'Current temperature','Modo':'Mode','Ventilação':'Fan speed','Direção do ar':'Air direction','Direção horizontal':'Horizontal swing','Predefinição':'Preset','Resfriar':'Cool','Aquecer':'Heat','Desumidificar':'Dry','Ventilar':'Fan only','Aquecer / resfriar':'Heat / cool','Baixa':'Low','Média':'Medium','Alta':'High','Silencioso':'Quiet','Forte':'Strong','Padrão':'Standard','Nenhum':'None','Sono':'Sleep','Vertical':'Vertical','Horizontal':'Horizontal','Ambos':'Both','Ligar / desligar':'Toggle power','Adicionar aos favoritos':'Add to favorites','Remover dos favoritos':'Remove from favorites','Diminuir temperatura':'Decrease temperature','Aumentar temperatura':'Increase temperature','Temperatura':'Temperature','Temperatura mínima':'Low temperature','Temperatura máxima':'High temperature','Brilho':'Brightness','Velocidade':'Speed','Posição':'Position','Abrir':'Open','Parar':'Stop','Fechar cortina':'Close cover','Ativar cena':'Activate scene','Iniciar limpeza':'Start cleaning','Pausar':'Pause','Voltar à base':'Return to dock','Localizar':'Locate','Sucção':'Suction','Bateria':'Battery','Limpar cômodos':'Clean rooms','Escolha os cômodos do mapa do aspirador.':'Choose rooms from the vacuum map.','Limpar selecionados':'Clean selected rooms','Ajustes do aspirador':'Vacuum settings','Informações e manutenção':'Information and maintenance','Leituras e informações':'Readings and information','Atualizar imagem':'Refresh image','Ver ao vivo':'Watch live','Não foi possível carregar a câmera. Confira a conexão e atualize a imagem.':'Could not load this camera. Check your connection and refresh the image.','Organizar':'Organize','Ocultar':'Hide','Mostrar':'Show','As preferências ficam apenas neste computador.':'These preferences stay on this computer.','Conexão salva de forma protegida.':'Connection saved securely.','A conexão está disponível apenas nesta sessão porque o cofre do sistema não está disponível.':'This connection is available for this session only because the system credential store is unavailable.','Esquecer conexão':'Forget connection','Esquecer a conexão salva neste computador?':'Forget the connection saved on this computer?','Downloads e versões':'Downloads and releases','Versão':'Version','Os cômodos não puderam ser atualizados. Tentaremos novamente automaticamente.':'Rooms could not be refreshed. We will retry automatically.','Energia e consumo':'Energy and consumption','aparelhos':'devices','aparelho':'device','Ação enviada':'Action sent','Os dados e comandos desta demonstração são simulados.':'Demonstration data and commands are simulated.','Conexão perdida. Tentando reconectar…':'Connection lost. Reconnecting…','A câmera está indisponível.':'This camera is unavailable.','Este aparelho está indisponível.':'This device is unavailable.','Aguarde a ação anterior.':'Wait for the previous action.','Este aparelho não oferece esse comando.':'This device does not support this action.'
};
Object.assign(english, {
  'Retomar':'Resume','Executar':'Run','Ajustes de limpeza':'Cleaning settings','Base e pano':'Dock and mop','Tapetes e navegação':'Carpets and navigation','Horários e som':'Schedules and sound','Manutenção':'Maintenance','Dados da limpeza':'Cleaning data','Avançado':'Advanced','Mapas, comandos internos e dados técnicos. Para alterações avançadas, use o Home Assistant.':'Maps, internal commands, and technical data. Use Home Assistant for advanced changes.','Modo de limpeza':'Cleaning mode','Passadas':'Passes','Água no pano':'Water on mop','Reforço em tapetes':'Carpet boost','Evitar tapetes':'Avoid carpets','Limpeza de tapetes':'Carpet cleaning','Rota de limpeza':'Cleaning route','Desvio de obstáculos':'Obstacle avoidance','Esvaziamento automático':'Auto emptying','Secagem automática':'Auto drying','Lavar o pano':'Wash mop','Lavagem com água quente':'Hot water wash','Temperatura de lavagem':'Wash temperature','Duração da secagem':'Drying time','Água na lavagem':'Wash water','Frequência de lavagem':'Wash frequency','Intervalo de lavagem':'Wash interval','Elevar o pano':'Lift mop','Usar detergente':'Use detergent','Não perturbe':'Do not disturb','Carregamento':'Charging','Vida útil da escova':'Brush life','Vida útil do filtro':'Filter life','Vida útil do pano':'Mop life','Vida útil do saco de pó':'Dust bag life','Detergente restante':'Detergent remaining','Tempo de limpeza':'Cleaning time','Área informada':'Reported area','Progresso':'Progress','Força do esvaziamento':'Emptying power','Frequência do esvaziamento':'Emptying frequency','Tanque de água suja':'Dirty water tank','Tanque de água limpa':'Clean water tank','Código de falha':'Fault code'
});
let state, tab = 'climate', room = null, detail = null, settings = false, organizing = false, query = '', toastTimer, interacting = false;
let selectedRooms = new Map();
let retainedFocusKey = null;
const root = document.getElementById('app');
const t = value => state?.locale === 'en-US' ? english[value] || value : value;
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[char]));
const d = e => e.entity_id.split('.')[0];
const available = e => e.state !== 'unavailable' && (e.state !== 'unknown' || ['button', 'scene', 'notify'].includes(d(e)));
const on = e => !['off', 'closed', 'standby', 'unavailable', 'unknown'].includes(e.state);
const supports = (e, flag) => ((e.attributes.supported_features || 0) & flag) !== 0;
const name = e => e.attributes.friendly_name || e.entity_id;
const areaName = e => state.areas.find(a => a.id === e.area_id)?.name || t('Sem cômodo');
const optionNames = { cool:'Resfriar',heat:'Aquecer',off:'Desligado',on:'Ligado',heat_cool:'Aquecer / resfriar',dry:'Desumidificar',fan_only:'Ventilar',low:'Baixa',medium:'Média',high:'Alta',silent:'Silencioso',quiet:'Silencioso',standard:'Padrão',strong:'Forte',none:'Nenhum',sleep:'Sono',vertical:'Vertical',horizontal:'Horizontal',both:'Ambos',open:'Aberta',closed:'Fechada',docked:'Na base',cleaning:'Limpando',paused:'Pausado',returning:'Voltando à base',idle:'Em espera',cooling:'Resfriando',heating:'Aquecendo',drying:'Desumidificando',fan:'Ventilando',charging:'Carregando',unavailable:'Indisponível',unknown:'Sem leitura' };
const display = value => t(optionNames[value] || value || 'Sem leitura');
const number = value => typeof value === 'number' && Number.isFinite(value) ? new Intl.NumberFormat(state.locale, { maximumFractionDigits: 1 }).format(value) : '—';
const disabled = e => !state.connected || !available(e) || state.pending.includes(e.entity_id) || state.pending.includes(detail);
const attr = value => esc(value);
const favorite = e => state.favorites.includes(e.entity_id);
const iconButton = (action, symbol, label, extra = '') => `<button type="button" class="icon" data-action="${action}" title="${attr(t(label))}" aria-label="${attr(t(label))}" ${extra}>${icon(symbol)}</button>`;
function star(e) { return `<button class="icon ${favorite(e) ? 'selected' : ''}" data-favorite="${attr(e.entity_id)}" aria-label="${attr(t(favorite(e) ? 'Remover dos favoritos' : 'Adicionar aos favoritos'))}" aria-pressed="${favorite(e)}">${icon('star')}</button>`; }
function canPower(e) {
  if (['light','switch'].includes(d(e))) return true;
  if (d(e) === 'fan') return supports(e, on(e) ? 32 : 16);
  return d(e) === 'climate' && (supports(e, on(e) ? 128 : 256) || (on(e) && e.attributes.hvac_modes?.includes('off')));
}
function power(e) { return canPower(e) ? `<button class="icon power ${on(e) ? 'is-on' : ''}" data-command="power" data-id="${attr(e.entity_id)}" ${disabled(e) ? 'disabled' : ''} aria-label="${attr(t('Ligar / desligar'))}" aria-pressed="${on(e)}">${icon('power')}</button>` : ''; }
function empty(title, copy, symbol = 'home') { return `<div class="empty">${icon(symbol)}<h2>${esc(t(title))}</h2><p>${esc(t(copy))}</p></div>`; }
function toast(text) { const box = document.getElementById('toast'); box.textContent = t(text); box.hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => box.hidden = true, 6500); }
async function act(task, success) { try { await task(); if (success) toast(success); } catch(error) { toast(error.message); } }
function render() {
  if (!state || interacting) return;
  const focus = document.activeElement?.id;
  if (document.activeElement?.dataset.focusKey) retainedFocusKey = document.activeElement.dataset.focusKey;
  const cursor = document.activeElement?.selectionStart;
  const contentScroll = document.querySelector('.content')?.scrollTop || 0;
  const draftServer = document.getElementById('server')?.value;
  const draftToken = state.connecting ? '' : document.getElementById('token')?.value;
  const connected = state.connected;
  document.documentElement.lang = state.locale;
  const setup = settings || (!connected && !state.entities.length);
  root.innerHTML = `<div class="shell"><header class="topbar"><div class="brand">${icon('home')}<span>HomeControl</span></div><span class="spacer"></span>${iconButton('settings','settings','Configurações',settings ? 'aria-pressed="true"' : '')}${iconButton('close','close','Fechar')}</header>
    ${!setup ? `<nav class="tabs" aria-label="HomeControl">${[['climate','wind','Ar-condicionado'],['rooms','rooms','Cômodos'],['favorites','star','Favoritos']].map(([key,symbol,label])=>`<button data-tab="${key}" aria-selected="${tab===key}" role="tab">${icon(symbol)}${esc(t(label))}</button>`).join('')}</nav>` : ''}
    ${state.demo && !settings ? `<div class="demo"><span>${esc(t('Demonstração'))}</span><button data-action="settings">${esc(t('Conectar minha casa'))}</button></div>` : ''}
    <main class="content">${state.status ? `<div class="notice" role="alert">${esc(t(state.status))}${!state.connecting && !setup ? `<button data-action="reconnect">${esc(t('Reconectar'))}</button>` : ''}</div>` : ''}${state.registryWarning && !setup ? `<div class="notice">${esc(t('Os cômodos não puderam ser atualizados. Tentaremos novamente automaticamente.'))}</div>` : ''}${setup ? setupView() : content()}</main>
    <footer class="footer"><span class="dot ${connected ? 'online' : ''}"></span><span class="server">${esc(t(state.connecting ? 'Conectando…' : connected ? state.demo ? 'Demonstração' : 'Conectado' : 'Desconectado'))}${!state.demo && connected ? ` · ${esc(new URL(state.server).host)}` : ''}</span><span>${esc(state.version)}</span></footer></div>`;
  const contentElement = document.querySelector('.content'); if (contentElement) contentElement.scrollTop = contentScroll;
  if (draftServer !== undefined && document.getElementById('server')) document.getElementById('server').value = draftServer;
  if (draftToken !== undefined && document.getElementById('token')) document.getElementById('token').value = draftToken;
  bind();
  const nextFocus = focus ? document.getElementById(focus) : [...root.querySelectorAll('[data-focus-key]')].find(el => el.dataset.focusKey === retainedFocusKey);
  if (nextFocus && !nextFocus.disabled) { nextFocus.focus({preventScroll:true}); if (typeof cursor === 'number' && ['text','search','url','password'].includes(nextFocus.type)) nextFocus.setSelectionRange(cursor,cursor); }
}
function setupView() {
  if (state.remembered && !settings) return `<section class="setup">${icon('home').replace('<svg ', '<svg class="logo" ')}<h1>${esc(t('Sua conexão está salva.'))}</h1><p>${esc(t('Vamos reconectar ao seu Home Assistant. Você não precisa informar o token novamente.'))}</p><button class="primary full" data-action="reconnect" ${state.connecting ? 'disabled' : ''}>${esc(t(state.connecting ? 'Conectando…' : 'Reconectar'))}</button><button class="secondary full" data-action="settings" ${state.connecting ? 'disabled' : ''}>${esc(t('Alterar conexão'))}</button></section>`;
  return `<section class="setup">${settings && state.connected ? `<button class="back" data-action="back-settings">${icon('back')}${esc(t('Voltar'))}</button>` : icon('home').replace('<svg ', '<svg class="logo" ')}<h1>${esc(t(settings ? 'Configurações' : 'Sua casa, mais perto.'))}</h1><p>${esc(t('Controle seus aparelhos pelo painel do HomeControl. Conecte seu Home Assistant para começar.'))}</p>
    <form id="connect-form"><label class="field"><span>${esc(t('Endereço do Home Assistant'))}</span><input id="server" type="url" placeholder="http://homeassistant.local:8123" value="${attr(state.server)}" required autocomplete="url" spellcheck="false" ${state.connecting ? 'disabled' : ''}></label>
    <label class="field"><span>${esc(t('Token de acesso'))}</span><span class="password"><input id="token" type="password" required autocomplete="off" spellcheck="false" ${state.connecting ? 'disabled' : ''}>${iconButton('show-token','eye','Mostrar token')}</span><small>${esc(t('No Home Assistant: Perfil → Segurança → Tokens de acesso de longa duração.'))}</small></label>
    <button class="primary full" type="submit" ${state.connecting ? 'disabled' : ''}>${esc(t(state.connecting ? 'Conectando…' : 'Conectar ao Home Assistant'))}</button></form>
    <button class="secondary full" data-action="demo" ${state.connecting ? 'disabled' : ''}>${esc(t('Explorar demonstração'))}</button>
    <p class="subtle">${esc(t(state.connected && !state.demo ? state.saved ? 'Conexão salva de forma protegida.' : 'A conexão está disponível apenas nesta sessão porque o cofre do sistema não está disponível.' : 'Seu token fica neste computador. Quando o cofre do sistema está disponível, a conexão é salva de forma protegida.'))}</p>
    ${settings ? `<button class="secondary full" data-action="updates">${esc(t('Downloads e versões'))}</button>${state.server ? `<button class="danger full" data-action="forget">${esc(t('Esquecer conexão'))}</button>` : ''}` : ''}</section>`;
}
function content() {
  if (organizing) return organizeView();
  if (detail) { const e = state.entities.find(x=>x.entity_id===detail); if (e) return detailView(e); detail = null; }
  if (tab === 'climate') {
    const all = state.entities.filter(e=>d(e)==='climate' && !state.hidden.includes(e.entity_id));
    if (!all.length) return empty('Sem ar-condicionado','Os aparelhos de clima conectados aparecerão aqui.','wind');
    const e = all.find(x=>x.entity_id===room) || all[0];
    return `${all.length > 1 ? `<label class="field device-picker"><span>${esc(t('Ar-condicionado'))}</span><select id="climate-picker">${all.map(x=>`<option value="${attr(x.entity_id)}" ${x===e?'selected':''}>${esc(name(x))} · ${esc(areaName(x))}</option>`).join('')}</select></label>` : ''}${climateView(e)}`;
  }
  const search = `<div class="search"><input type="search" id="search" placeholder="${attr(t('Buscar aparelho ou cômodo'))}" aria-label="${attr(t('Buscar aparelho ou cômodo'))}" value="${attr(query)}"></div>`;
  let all = state.entities.filter(e=>!state.hidden.includes(e.entity_id));
  if (tab === 'favorites') all = all.filter(favorite);
  if (query) { const q = query.toLocaleLowerCase(state.locale); all = all.filter(e=>[name(e),areaName(e),t({light:'Luzes',climate:'Ar-condicionado',vacuum:'Aspirador',camera:'Câmeras'}[d(e)]||d(e))].some(x=>x.toLocaleLowerCase(state.locale).includes(q))); }
  if (tab === 'favorites') return search + (all.length ? all.map(deviceRow).join('') : empty(query ? 'Nenhum aparelho encontrado' : 'Sem favoritos por enquanto',query ? 'Tente outro nome ou tipo de aparelho.' : 'Marque a estrela de um aparelho para encontrá-lo aqui.','star'));
  if (query) return search + (all.length ? all.map(deviceRow).join('') : empty('Nenhum aparelho encontrado','Tente outro nome ou tipo de aparelho.'));
  if (room) {
    const items = all.filter(e=>(e.area_id || 'unassigned')===room);
    const daily = items.filter(e=>!technical(e)); const secondary = items.filter(technical);
    return `<button class="back" data-action="rooms-back">${icon('back')}${esc(t('Cômodos'))}</button><h2 class="section-title">${esc(state.areas.find(a=>a.id===room)?.name || t('Sem cômodo'))}</h2>${daily.map(deviceRow).join('')}${secondary.length ? `<details><summary>${esc(t('Leituras e informações'))} · ${secondary.length}</summary>${secondary.map(deviceRow).join('')}</details>` : ''}`;
  }
  const areas = [...state.areas, { id:'unassigned',name:t('Sem cômodo') }].map(a=>({...a,items:all.filter(e=>(e.area_id||'unassigned')===a.id)})).filter(a=>a.items.length);
  return search + areas.map(a=>`<button class="room" data-room="${attr(a.id)}">${icon('home')}<span class="copy"><strong>${esc(a.name)}</strong><small>${a.items.length} ${esc(t(a.items.length===1?'aparelho':'aparelhos'))}</small></span>${icon('next').replace('<svg ','<svg class="chevron" ')}</button>`).join('') + `<button class="text-action full" data-action="organize">${esc(t('Organizar'))}</button>`;
}
function technical(e) { return e.category || (['sensor','binary_sensor'].includes(d(e)) && !['temperature','humidity','carbon_dioxide','moisture','illuminance'].includes(e.attributes.device_class)); }
function summary(e) {
  if (!available(e)) return t('Indisponível');
  if (d(e)==='climate') return `${display(e.state)} · ${number(e.attributes.temperature)}${e.attributes.temperature_unit||'°C'}`;
  if (d(e)==='scene') return t('Ativar cena');
  return `${display(e.state)}${e.attributes.unit_of_measurement ? ` ${e.attributes.unit_of_measurement}` : ''}`;
}
function deviceRow(e) { return `<div class="device"><button class="device-open" data-detail="${attr(e.entity_id)}">${icon(d(e)==='climate'?'wind':d(e))}<span class="copy"><strong>${esc(name(e))}</strong><small>${esc(summary(e))}</small></span></button>${power(e)}${star(e)}</div>`; }
function heading(e) { return `<div class="heading-row"><div class="copy"><h1>${esc(name(e))}</h1><div class="room-label">${esc(areaName(e))}${!available(e)?` · ${esc(t('Indisponível'))}`:''}</div></div>${star(e)}${power(e)}</div>`; }
function selectControl(e,key,verb,label,symbol,feature) {
  const values = e.attributes[key]; if (!Array.isArray(values) || !values.length || (feature && !supports(e,feature))) return '';
  const selected = e.attributes[{hvac:'state',fan:'fan_mode',swing:'swing_mode','swing-horizontal':'swing_horizontal_mode',preset:'preset_mode'}[verb]];
  return `<label class="option">${icon(symbol)}<span>${esc(t(label))}</span><select data-verb="${verb}" data-id="${attr(e.entity_id)}" aria-label="${attr(t(label))}" ${disabled(e)?'disabled':''}>${values.map(x=>`<option value="${attr(x)}" ${x===(verb==='hvac'?e.state:selected)?'selected':''}>${esc(display(x))}</option>`).join('')}</select></label>`;
}
function climateView(e) {
  const a=e.attributes; const range=supports(e,2)&&(['heat_cool','auto'].includes(e.state)||!supports(e,1));
  const presets = a.preset_modes || [];
  const ecoValue = presets.find(value => value.toLowerCase() === 'eco');
  const ecoOff = presets.find(value => value === 'none') || presets.find(value => value !== ecoValue);
  const eco = supports(e,16) && ecoValue && ecoOff ? `<button class="secondary ${a.preset_mode===ecoValue?'selected':''}" data-command="preset" data-id="${attr(e.entity_id)}" data-value="${attr(a.preset_mode===ecoValue?ecoOff:ecoValue)}" aria-pressed="${a.preset_mode===ecoValue}" ${disabled(e)?'disabled':''}>${icon('leaf')}Eco</button>` : '';
  const target=range ? `${number(a.target_temp_low)}–${number(a.target_temp_high)}` : number(a.temperature);
  const lo=a.min_temp??(a.temperature_unit==='°F'?45:7), hi=a.max_temp??(a.temperature_unit==='°F'?95:35),step=a.target_temp_step||0.5;
  const slider=(verb,value,label)=>`<div class="climate-slider"><button class="icon" data-adjust="${verb}" data-id="${attr(e.entity_id)}" data-value="${Number(value)-step}" aria-label="${attr(t('Diminuir temperatura'))}" ${disabled(e)||!Number.isFinite(value)||value<=lo?'disabled':''}>${icon('minus')}</button><input type="range" data-verb="${verb}" data-id="${attr(e.entity_id)}" aria-label="${attr(t(label))}" min="${lo}" max="${hi}" step="${step}" value="${value??lo}" ${disabled(e)||!Number.isFinite(value)?'disabled':''}><button class="icon" data-adjust="${verb}" data-id="${attr(e.entity_id)}" data-value="${Number(value)+step}" aria-label="${attr(t('Aumentar temperatura'))}" ${disabled(e)||!Number.isFinite(value)||value>=hi?'disabled':''}>${icon('plus')}</button></div>`;
  return `${heading(e)}<div class="climate-art"><img src="../assets/air-conditioner.png" alt="">${on(e)&&available(e)?'<div class="air" aria-hidden="true"><span></span><span></span><span></span></div>':''}</div><div class="temperature-block"><div class="temperature">${target}<small>${esc(a.temperature_unit||'°C')}</small></div>${eco}</div><div class="current">${esc(t('Temperatura atual'))} ${number(a.current_temperature)}${esc(a.temperature_unit||'°C')}</div>${range ? slider('temperature-low',a.target_temp_low,'Temperatura mínima')+slider('temperature-high',a.target_temp_high,'Temperatura máxima') : supports(e,1)?slider('temperature',a.temperature,'Temperatura'):''}<div class="options">${selectControl(e,'hvac_modes','hvac','Modo','mode')}${selectControl(e,'fan_modes','fan','Ventilação','fan',8)}${selectControl(e,'swing_modes','swing','Direção do ar','swing',32)}${selectControl(e,'preset_modes','preset','Predefinição','leaf',16)}${selectControl(e,'swing_horizontal_modes','swing-horizontal','Direção horizontal','swing',512)}</div><div class="climate-status">${esc(display(a.hvac_action||e.state))}</div>`;
}
function slider(e,verb,label,value,min=0,max=100,step=1,unit='%') { return `<div class="control-field"><label>${esc(t(label))}<output>${number(value)}${esc(unit)}</output></label><input type="range" data-verb="${verb}" data-id="${attr(e.entity_id)}" aria-label="${attr(t(label))}" min="${min}" max="${max}" step="${step}" value="${value??min}" ${disabled(e)||!Number.isFinite(value)?'disabled':''}></div>`; }
function actionButton(e,verb,label,symbol='power',value) { return `<button class="secondary" data-command="${verb}" data-id="${attr(e.entity_id)}" ${value!==undefined?`data-value="${attr(value)}"`:''} ${disabled(e)?'disabled':''}>${icon(symbol)}${esc(t(label))}</button>`; }
function vacuumKey(e) { return `${e.entity_id.replace(/_[pae]_\d+_\d+$/,'')} ${name(e)}`.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase(); }
function vacuumPrimary(e) {
  if(d(e)!=='select') return false;
  const key=vacuumKey(e), excluded=['carpet','tapete','avoidance','wash','dry','dust_arrest','worry_free'].some(x=>key.includes(x));
  const speeds=new Set(['silent','quiet','gentle','standard','normal','strong','turbo','max','low','medium','high']);
  const values=new Set((e.attributes.options||[]).map(x=>String(x).toLowerCase()));
  const suction=['suction','suction_level','suction_power','fan_speed'].some(x=>key.includes(x)) || (key.includes('mode')&&!excluded&&values.size>=2&&[...values].every(x=>speeds.has(x)));
  return !excluded&&(suction||['sweep_mop_type','cleaning_mode','clean_times','mop_water_output_level','water_level','water_output_for_mopping'].some(x=>key.includes(x)));
}
function vacuumTitle(e) {
  const key=vacuumKey(e);
  const labels=[['sweep_mop_type','Modo de limpeza'],['cleaning_mode','Modo de limpeza'],['clean_times','Passadas'],['mop_water_output_level','Água no pano'],['water_output_for_mopping','Água no pano'],['water_level','Água no pano'],['carpet_boost','Reforço em tapetes'],['carpet_avoidance','Evitar tapetes'],['carpet_cleaning_method','Limpeza de tapetes'],['sweep_route','Rota de limpeza'],['obstacle_avoidance_strategy','Desvio de obstáculos'],['auto_dust_arrest','Esvaziamento automático'],['auto_mop_dry','Secagem automática'],['enable_mop_wash','Lavar o pano'],['hot_water_mop_wash','Lavagem com água quente'],['wash_mop_water_temperature','Temperatura de lavagem'],['drying_time','Duração da secagem'],['water_output_for_washing_mop','Água na lavagem'],['frequency_mop_wash','Frequência de lavagem'],['frequency_mop_wash_by_time','Intervalo de lavagem'],['mop_auto_lift','Elevar o pano'],['use_detergent','Usar detergente'],['no_disturb','Não perturbe'],['do_not_disturb','Não perturbe'],['volume','Volume'],['battery_level','Bateria'],['charging_state','Carregamento'],['brush_life_level','Vida útil da escova'],['filter_life_level','Vida útil do filtro'],['mop_life_level','Vida útil do pano'],['dust_bag_life_level','Vida útil do saco de pó'],['detergent_left_level','Detergente restante'],['cleaning_time','Tempo de limpeza'],['cleaning_area','Área informada'],['cleaning_progress','Progresso'],['auto_dust_arrest_power_level','Força do esvaziamento'],['dust_arrest_frequency','Frequência do esvaziamento'],['sewage_tank_status','Tanque de água suja'],['water_tank_status','Tanque de água limpa'],['device_fault','Código de falha']];
  if(key.includes('suction')) return t('Sucção');
  return t(labels.find(([suffix])=>key.includes(suffix))?.[1]||name(e));
}
function vacuumSettingRow(robot,e) {
  const entityID=attr(e.entity_id), vacuumID=attr(robot.entity_id), label=esc(vacuumTitle(e)), type=d(e);
  if(['sensor','binary_sensor'].includes(type)) return `<div class="device vacuum-reading"><span class="copy"><strong>${label}</strong><small>${esc(summary(e))}</small></span></div>`;
  let control='';
  if(type==='select'&&e.vacuum_section!=='advanced') control=`<select data-id="${entityID}" data-vacuum="${vacuumID}" data-verb="select" aria-label="${attr(vacuumTitle(e))}" ${disabled(robot)||!available(e)?'disabled':''}>${(e.attributes.options||[]).map(x=>`<option value="${attr(x)}" ${x===e.state?'selected':''}>${esc(display(x))}</option>`).join('')}</select>`;
  else if(type==='number'&&e.vacuum_section!=='advanced'&&Number.isFinite(e.attributes.min)&&Number.isFinite(e.attributes.max)) control=`<input type="range" data-id="${entityID}" data-vacuum="${vacuumID}" data-verb="number" aria-label="${attr(vacuumTitle(e))}" min="${e.attributes.min}" max="${e.attributes.max}" step="${e.attributes.step||1}" value="${Number(e.state)||0}" ${disabled(robot)||!available(e)?'disabled':''}>`;
  else if(type==='switch'&&e.vacuum_section!=='advanced') control=`<button class="secondary" data-id="${entityID}" data-vacuum="${vacuumID}" data-command="power" ${disabled(robot)||!available(e)?'disabled':''}>${esc(display(e.state))}</button>`;
  else if(type==='button'&&available(e)) control=`<button class="secondary" data-id="${entityID}" data-vacuum="${vacuumID}" data-command="press" ${disabled(robot)?'disabled':''}>${esc(t('Executar'))}</button>`;
  else control=`<span class="vacuum-value">${esc(e.state==='unknown'?'Sem leitura':display(e.state))}</span>`;
  return `<div class="vacuum-setting"><span>${label}</span>${control}</div>`;
}
function vacuumGroup(robot,section,items) {
  if(!items.length) return '';
  const titles={cleaning:'Ajustes de limpeza',dock:'Base e pano',navigation:'Tapetes e navegação',schedule:'Horários e som',maintenance:'Manutenção',activity:'Dados da limpeza',advanced:'Avançado'};
  const title=esc(t(titles[section]));
  const note=section==='advanced'?`<p class="subtle">${esc(t('Mapas, comandos internos e dados técnicos. Para alterações avançadas, use o Home Assistant.'))}</p>`:'';
  return `<details class="vacuum-group"><summary>${title}<span class="group-count">${items.length}</span></summary>${note}${items.map(item=>vacuumSettingRow(robot,item)).join('')}</details>`;
}
function detailView(e) {
  const back=`<button class="back" data-action="detail-back">${icon('back')}${esc(t('Voltar'))}</button>`;
  if (d(e)==='climate') return back+climateView(e);
  let body = `${back}${heading(e)}`;
  if (d(e)==='camera') return body+`<img class="camera-preview" id="camera-image" src="homecontrol://camera/${encodeURIComponent(e.entity_id)}?t=${Date.now()}" alt="${attr(name(e))}"><div class="camera-error" id="camera-error" hidden>${esc(t('Não foi possível carregar a câmera. Confira a conexão e atualize a imagem.'))}</div><div class="controls">${actionButton(e,'snapshot','Atualizar imagem','refresh')}${actionButton(e,'live','Ver ao vivo','camera')}</div>`;
  body+=`<div class="detail-icon">${icon(d(e))}</div><div class="reading">${esc(display(e.state))}${e.attributes.unit_of_measurement?` <small>${esc(e.attributes.unit_of_measurement)}</small>`:''}</div>`;
  const a=e.attributes;
  if(d(e)==='light'&&a.supported_color_modes?.some(x=>!['onoff','unknown'].includes(x))) body+=slider(e,'brightness','Brilho',Number.isFinite(a.brightness)?Math.round(a.brightness/2.55):e.state==='off'?0:null);
  if(d(e)==='fan'&&supports(e,1)) body+=slider(e,'percentage','Velocidade',a.percentage,0,100,a.percentage_step||1);
  if(d(e)==='fan'&&supports(e,8)&&a.preset_modes?.length) body+=`<div class="options">${selectControl(e,'preset_modes','preset','Predefinição','fan',8)}</div>`;
  if(d(e)==='cover') { if(supports(e,4)) body+=slider(e,'position','Posição',a.current_position); body+=`<div class="controls">${supports(e,1)?actionButton(e,'open','Abrir','plus'):''}${supports(e,8)?actionButton(e,'stop','Parar','stop'):''}${supports(e,2)?actionButton(e,'close','Fechar cortina','minus'):''}</div>`; }
  if(d(e)==='scene') body+=`<div class="controls">${actionButton(e,'activate','Ativar cena','play')}</div>`;
  if(d(e)==='vacuum') body+=vacuumView(e);
  return body;
}
function vacuumView(e) {
  const a=e.attributes;
  const buttons=[[e.state==='paused'?'start':'start',e.state==='paused'?'Retomar':'Iniciar limpeza','play',8192,!['cleaning','returning'].includes(e.state)],['pause','Pausar','pause',4,e.state==='cleaning'],['stop','Parar','stop',8,['cleaning','paused','returning'].includes(e.state)],['return_to_base','Voltar à base','home',16,!['docked','returning'].includes(e.state)],['locate','Localizar','home',512,true]];
  let body=`${Number.isFinite(a.battery_level)?`<div class="current">${esc(t('Bateria'))} ${number(a.battery_level)}%</div>`:''}<div class="controls">${buttons.filter(x=>supports(e,x[3])&&x[4]).map(([verb,label,symbol])=>actionButton(e,verb,label,symbol)).join('')}</div>`;
  const related=e.related||[]; const primary=related.filter(vacuumPrimary).slice(0,4); const primaryIDs=new Set(primary.map(x=>x.entity_id));
  const standardSuction=!primary.some(x=>vacuumKey(x).includes('suction'))&&supports(e,32)&&a.fan_speed_list?.length;
  if(primary.length||standardSuction) body+=`<div class="options vacuum-primary">${standardSuction?`<label class="option">${icon('fan')}<span>${esc(t('Sucção'))}</span><select data-id="${attr(e.entity_id)}" data-verb="fan" ${disabled(e)?'disabled':''}>${a.fan_speed_list.map(x=>`<option value="${attr(x)}" ${a.fan_speed===x?'selected':''}>${esc(display(x))}</option>`).join('')}</select></label>`:''}${primary.map(x=>`<label class="option">${icon(vacuumKey(x).includes('water')||vacuumKey(x).includes('mop')?'water':'mode')}<span>${esc(vacuumTitle(x))}</span><select data-id="${attr(x.entity_id)}" data-vacuum="${attr(e.entity_id)}" data-verb="select" ${disabled(e)||!available(x)?'disabled':''}>${(x.attributes.options||[]).map(value=>`<option value="${attr(value)}" ${value===x.state?'selected':''}>${esc(display(value))}</option>`).join('')}</select></label>`).join('')}</div>`;
  if(e.roomMap) {
    const key=e.entity_id+':'+e.roomMap.mapID; const selected=selectedRooms.get(key)||new Set();
    body+=`<h2 class="section-title">${esc(t('Limpar cômodos'))}</h2><p class="subtle">${esc(t('Escolha os cômodos do mapa do aspirador.'))}</p><div class="room-checks">${e.roomMap.rooms.map(r=>`<label><input type="checkbox" data-map="${attr(key)}" value="${attr(r.id)}" ${selected.has(r.id)?'checked':''} ${disabled(e)?'disabled':''}>${esc(r.name)}</label>`).join('')}</div><button class="primary full" data-action="clean-rooms" data-id="${attr(e.entity_id)}" data-map="${attr(key)}" ${disabled(e)||!selected.size?'disabled':''}>${esc(t('Limpar selecionados'))}</button>`;
  }
  const sections=['cleaning','dock','navigation','schedule','maintenance','activity','advanced'];
  for(const section of sections) {
    const items=related.filter(r=>r.vacuum_section===section&&!primaryIDs.has(r.entity_id)&&!r.entity_id.includes('room_information'));
    body+=vacuumGroup(e,section,items);
  }
  return body;
}
function organizeView(){return `<button class="back" data-action="organize-back">${icon('back')}${esc(t('Voltar'))}</button><h2 class="section-title">${esc(t('Organizar'))}</h2><p class="subtle">${esc(t('As preferências ficam apenas neste computador.'))}</p>${state.entities.map(e=>`<div class="organize-row"><span>${esc(name(e))}</span><button data-hide="${attr(e.entity_id)}">${esc(t(state.hidden.includes(e.entity_id)?'Mostrar':'Ocultar'))}</button></div>`).join('')}`;}
function navigate(fn){fn();query='';render();document.querySelector('.content')?.scrollTo(0,0);}
function bind(){
  root.querySelectorAll('button,input,select,summary').forEach(el => {
    const data = Object.fromEntries(Object.entries(el.dataset).filter(([key]) => !['focusKey','value'].includes(key)).sort(([a],[b]) => a.localeCompare(b)));
    el.dataset.focusKey = JSON.stringify([el.tagName, el.id, data, el.dataset.adjust ? el.getAttribute('aria-label') : null, el.type === 'checkbox' ? el.value : null]);
    el.addEventListener('focus', () => retainedFocusKey = el.dataset.focusKey);
  });
  root.querySelectorAll('[data-tab]').forEach(el=>el.onclick=()=>navigate(()=>{tab=el.dataset.tab;room=null;detail=null;organizing=false;}));
  root.querySelectorAll('[data-room]').forEach(el=>el.onclick=()=>navigate(()=>room=el.dataset.room));
  root.querySelectorAll('[data-detail]').forEach(el=>el.onclick=()=>navigate(()=>detail=el.dataset.detail));
  root.querySelectorAll('[data-favorite]').forEach(el=>el.onclick=()=>act(async()=>{state=await window.home.preference('favorites',el.dataset.favorite);render();}));
  root.querySelectorAll('[data-hide]').forEach(el=>el.onclick=()=>act(async()=>{state=await window.home.preference('hidden',el.dataset.hide);render();}));
  root.querySelectorAll('[data-command]').forEach(el=>el.onclick=()=>{
    if(el.dataset.command==='snapshot'){render();return;}
    if(el.dataset.command==='live'){act(()=>window.home.camera(el.dataset.id));return;}
    act(()=>window.home.command({id:el.dataset.id,verb:el.dataset.command,value:el.dataset.value,vacuumID:el.dataset.vacuum}),d(state.entities.find(e=>e.entity_id===el.dataset.id)||{entity_id:el.dataset.id})==='scene'?'Ação enviada':null);
  });
  root.querySelectorAll('[data-adjust]').forEach(el=>el.onclick=()=>act(()=>window.home.command({id:el.dataset.id,verb:el.dataset.adjust,value:Number(el.dataset.value)})));
  root.querySelectorAll('[data-verb]').forEach(el=>{
    el.onchange=()=>{interacting=false;act(()=>window.home.command({id:el.dataset.id,verb:el.dataset.verb,value:el.type==='range'?Number(el.value):el.value,vacuumID:el.dataset.vacuum}));};
    if(el.type==='range'){
      el.onpointerdown=()=>interacting=true;
      el.oninput=()=>{const output=el.closest('.control-field')?.querySelector('output');if(output)output.textContent=number(Number(el.value));};
    }
  });
  root.querySelectorAll('[data-map][type=checkbox]').forEach(el=>el.onchange=()=>{const set=selectedRooms.get(el.dataset.map)||new Set();el.checked?set.add(el.value):set.delete(el.value);selectedRooms.set(el.dataset.map,set);render();});
  root.querySelectorAll('[data-action]').forEach(el=>el.onclick=()=>{
    const action=el.dataset.action;
    if(action==='close'){act(()=>window.home.window('close'));return;}
    if(action==='settings'){navigate(()=>{settings=!settings;});return;}
    if(action==='back-settings'){navigate(()=>settings=false);return;}
    if(action==='detail-back'){navigate(()=>detail=null);return;}
    if(action==='rooms-back'){navigate(()=>room=null);return;}
    if(action==='organize'){navigate(()=>organizing=true);return;}
    if(action==='organize-back'){navigate(()=>organizing=false);return;}
    if(action==='demo'){act(async()=>{state=await window.home.demo();settings=false;room=null;detail=null;tab='climate';render();});return;}
    if(action==='reconnect'){act(()=>window.home.reconnect());return;}
    if(action==='updates'){act(()=>window.home.updates());return;}
    if(action==='show-token'){const field=document.getElementById('token');field.type=field.type==='password'?'text':'password';return;}
    if(action==='forget'){if(window.confirm(t('Esquecer a conexão salva neste computador?')))act(async()=>{state=await window.home.forget();settings=false;detail=null;room=null;render();});return;}
    if(action==='clean-rooms'){act(()=>window.home.command({id:el.dataset.id,verb:'rooms',value:[...(selectedRooms.get(el.dataset.map)||[])]}));}
  });
  const form=document.getElementById('connect-form');
  if(form)form.onsubmit=event=>{event.preventDefault();const input={server:document.getElementById('server').value,token:document.getElementById('token').value};act(async()=>{await window.home.connect(input);state=await window.home.get();settings=false;room=null;detail=null;render();});};
  const picker=document.getElementById('climate-picker');if(picker)picker.onchange=()=>{room=picker.value;render();};
  const search=document.getElementById('search');if(search)search.oninput=()=>{query=search.value;render();};
  const image=document.getElementById('camera-image');if(image)image.onerror=()=>{image.hidden=true;document.getElementById('camera-error').hidden=false;};
}
window.addEventListener('pointerup',()=>{interacting=false;});
window.addEventListener('keydown',event=>{if(event.key==='Escape'){if(detail)navigate(()=>detail=null);else if(settings)navigate(()=>settings=false);else act(()=>window.home.window('close'));}});
window.home.changed(value=>{state=value;render();});
window.__homecontrolReady=window.home.get().then(value=>{state=value;render();});
