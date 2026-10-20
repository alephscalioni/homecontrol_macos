const domain = e => e.entity_id.split('.')[0];
const available = e => e && e.state !== 'unavailable' && (e.state !== 'unknown' || ['button', 'notify', 'scene'].includes(domain(e)));
const features = (e, bit) => ((e.attributes?.supported_features || 0) & bit) !== 0;
const options = (e, key) => Array.isArray(e.attributes?.[key]) ? e.attributes[key].filter(x => typeof x === 'string') : [];
const safeCover = e => domain(e) === 'cover' && !['garage', 'gate', 'door'].includes(e.attributes?.device_class);
const supported = e => ['climate', 'light', 'switch', 'fan', 'scene', 'sensor', 'binary_sensor', 'camera', 'vacuum'].includes(domain(e)) || safeCover(e);
const on = e => available(e) && !['off', 'closed', 'standby'].includes(e.state);
const dockKeys = ['start_dust_arrest', 'start_mop_wash', 'stop_mop_wash', 'start_dry', 'stop_dry', 'start_self_cleaning_of_the_station', 'start_base_station_cleaning', 'stop_self_cleaning_of_the_station', 'empty_base_station_water_tank'];
const vacuumSection = (entity, entry = {}) => {
  const d = domain(entity);
  const id = entity.entity_id.replace(/_[pae]_\d+_\d+$/, '').toLowerCase();
  const name = String(entity.attributes?.friendly_name || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  const key = `${id} ${name}`;
  const has = (...terms) => terms.some(term => key.includes(term));
  if (dockKeys.some(term => key.includes(term))) return 'dock';
  const excluded = has('carpet', 'tapete', 'avoidance', 'wash', 'dry', 'dust_arrest', 'worry_free');
  const options = new Set((entity.attributes?.options || []).map(value => String(value).toLowerCase()));
  const speeds = new Set(['silent', 'quiet', 'gentle', 'standard', 'normal', 'strong', 'turbo', 'max', 'low', 'medium', 'high']);
  const suction = d === 'select' && (has('suction', 'suction_level', 'suction_power', 'fan_speed') || (has('mode') && !excluded && options.size >= 2 && [...options].every(value => speeds.has(value))));
  const primary = d === 'select' && !excluded && (suction || has('sweep_mop_type', 'cleaning_mode', 'clean_times', 'mop_water_output_level', 'water_level', 'water_output_for_mopping'));
  if (primary) return 'cleaning';
  if (has('life_level', 'left_time', 'left_level', 'remaining', 'vida_util', 'battery', 'bateria', 'tank_status', 'charging_state', 'device_fault') && !has('dry_left_time')) return 'maintenance';
  if (has('map_', '_map', 'trajectory', 'position', 'firmware', 'frameware', 'download', '_voice', 'stream', 'video', 'flash_light', '_info', '_result', 'fault_ids', 'zone_ids', 'room_information', '_config', '_cfg', '_dialog', '_object', '_notice', 'updata', '_sill', 'remote', 'locked', 'control_lock') || ['button', 'text', 'event', 'notify'].includes(d) || entry.entity_category === 'diagnostic') return 'advanced';
  if (has('no_disturb', 'do_not_disturb', 'nao_perturbe', 'volume', 'schedule', 'order_clean', 'enable_time_period', 'sleep', 'alarm')) return 'schedule';
  if (has('carpet', 'tapete', 'avoidance', 'detection', 'sweep_route', 'edge_', 'outer_swing', 'outswing')) return 'navigation';
  if (has('mop_wash', 'washing_mop', 'wash_mop', 'dry', 'dust_arrest', 'auto_water', 'detergent', 'cut_hair', 'water_change', 'mop_auto_lift', 'repeat_wash')) return 'dock';
  if (['select', 'number', 'switch'].includes(d)) return 'cleaning';
  if (has('cleaning', 'clean_time', 'clean_area', 'sweep_mop_status', 'mop_status', 'statistical', 'progress')) return 'activity';
  return 'advanced';
};
function vacuumOwners(entities, registry) {
  const registryEntities = registry?.entities || [];
  const entries = new Map(registryEntities.map(entry => [entry.entity_id, entry]));
  const robotsByDevice = new Map();
  for (const robot of entities.filter(entity => domain(entity) === 'vacuum')) {
    const deviceID = entries.get(robot.entity_id)?.device_id;
    if (!deviceID) continue;
    const robots = robotsByDevice.get(deviceID) || [];
    robots.push(robot.entity_id); robotsByDevice.set(deviceID, robots);
  }
  const childDomains = new Set(['sensor', 'binary_sensor', 'switch', 'select', 'number', 'button', 'text', 'event', 'notify']);
  const owners = new Map();
  for (const entity of entities) {
    if (!childDomains.has(domain(entity))) continue;
    const deviceID = entries.get(entity.entity_id)?.device_id;
    const robots = deviceID && robotsByDevice.get(deviceID);
    if (robots?.length === 1) owners.set(entity.entity_id, robots[0]);
  }
  return owners;
}
function related(vacuum, entities, registry) {
  const owners = vacuumOwners(entities, registry);
  const visible = new Set((registry?.entities || []).filter(entry => !entry.disabled_by && !entry.hidden_by).map(entry => entry.entity_id));
  return entities.filter(entity => entity.entity_id !== vacuum.entity_id && owners.get(entity.entity_id) === vacuum.entity_id && visible.has(entity.entity_id));
}
function roomMap(vacuum, entities, registry) {
  const relatives = related(vacuum, entities, registry);
  const source = relatives.find(x => domain(x) === 'sensor' && x.entity_id.includes('room_information') && x.state.length < 256000);
  const action = relatives.find(x => domain(x) === 'notify' && available(x) && x.entity_id.includes('start_vacuum_room_sweep') && registry.entities.find(r => r.entity_id === x.entity_id)?.platform === 'xiaomi_home' && /\(str\)\]$/.test(x.attributes?.['action params'] || '') && ((x.attributes['action params'].match(/\(/g) || []).length === 1));
  if (!source || !action) return null;
  try {
    const data = JSON.parse(source.state);
    const identifier = value => /^(0|[1-9]\d{0,9})$/.test(String(value)) && Number(value) <= 2147483647;
    if (!identifier(data.map_uid) || !Array.isArray(data.rooms)) return null;
    const seen = new Set();
    const rooms = data.rooms.slice(0, 100).filter(x => identifier(x.id) && !seen.has(String(x.id)) && seen.add(String(x.id))).map(x => ({ id: String(x.id), name: String(x.name || x.id).slice(0, 100) }));
    return rooms.length ? { rooms, actionID: action.entity_id, mapID: String(data.map_uid) } : null;
  } catch { return null; }
}
function command(entity, verb, value, context = {}) {
  if (!available(entity)) throw new Error('Este aparelho está indisponível.');
  const d = domain(entity); let service; let data = {};
  const reject = () => { throw new Error('Este aparelho não oferece esse comando.'); };
  const choose = (key, field, name) => { if (!options(entity, key).includes(value)) reject(); service = name; data[field] = value; };
  const number = (low, high, step = 1) => {
    if (typeof value !== 'number' || !Number.isFinite(value)) reject();
    return Number(Math.min(high, Math.max(low, low + Math.round((value - low) / step) * step)).toFixed(3));
  };
  if (verb === 'power') {
    if (['light', 'switch'].includes(d) || (d === 'fan' && features(entity, on(entity) ? 32 : 16))) service = on(entity) ? 'turn_off' : 'turn_on';
    else if (d === 'climate' && features(entity, on(entity) ? 128 : 256)) service = on(entity) ? 'turn_off' : 'turn_on';
    else if (d === 'climate' && on(entity) && options(entity, 'hvac_modes').includes('off')) { service = 'set_hvac_mode'; data.hvac_mode = 'off'; }
    else reject();
  } else if (d === 'climate') {
    const a = entity.attributes;
    const lo = a.min_temp ?? (a.temperature_unit === '°F' ? 45 : 7), hi = Math.max(lo + 0.1, a.max_temp ?? (a.temperature_unit === '°F' ? 95 : 35));
    if (verb === 'temperature' && features(entity, 1) && !(features(entity, 2) && ['heat_cool', 'auto'].includes(entity.state))) { service = 'set_temperature'; data.temperature = number(lo, hi, Math.max(0.1, a.target_temp_step || 0.5)); }
    else if (['temperature-low', 'temperature-high'].includes(verb) && features(entity, 2) && Number.isFinite(a.target_temp_low) && Number.isFinite(a.target_temp_high)) {
      const v = number(lo, hi, Math.max(0.1, a.target_temp_step || 0.5)); service = 'set_temperature';
      data.target_temp_low = verb === 'temperature-low' ? Math.min(v, a.target_temp_high) : a.target_temp_low;
      data.target_temp_high = verb === 'temperature-high' ? Math.max(v, a.target_temp_low) : a.target_temp_high;
    } else if (verb === 'hvac') choose('hvac_modes', 'hvac_mode', 'set_hvac_mode');
    else if (verb === 'fan' && features(entity, 8)) choose('fan_modes', 'fan_mode', 'set_fan_mode');
    else if (verb === 'swing' && features(entity, 32)) choose('swing_modes', 'swing_mode', 'set_swing_mode');
    else if (verb === 'swing-horizontal' && features(entity, 512)) choose('swing_horizontal_modes', 'swing_horizontal_mode', 'set_swing_horizontal_mode');
    else if (verb === 'preset' && features(entity, 16)) choose('preset_modes', 'preset_mode', 'set_preset_mode');
    else reject();
  } else if (d === 'light' && verb === 'brightness' && options(entity, 'supported_color_modes').some(x => !['onoff', 'unknown'].includes(x))) { service = 'turn_on'; data.brightness_pct = number(0, 100); }
  else if (d === 'fan' && verb === 'percentage' && features(entity, 1)) { service = 'set_percentage'; data.percentage = number(0, 100, entity.attributes.percentage_step || 1); }
  else if (d === 'fan' && verb === 'preset' && features(entity, 8)) choose('preset_modes', 'preset_mode', 'set_preset_mode');
  else if (safeCover(entity) && ['open', 'close', 'stop', 'position'].includes(verb)) {
    if (!features(entity, { open: 1, close: 2, stop: 8, position: 4 }[verb])) reject();
    service = verb === 'position' ? 'set_cover_position' : verb + '_cover'; if (verb === 'position') data.position = number(0, 100);
  } else if (d === 'scene' && verb === 'activate') service = 'turn_on';
  else if (d === 'vacuum' && ['start', 'pause', 'stop', 'return_to_base', 'locate'].includes(verb)) {
    if (!features(entity, { start: 8192, pause: 4, stop: 8, return_to_base: 16, locate: 512 }[verb])) reject();
    if ((verb === 'start' && ['cleaning', 'returning'].includes(entity.state)) || (verb === 'pause' && entity.state !== 'cleaning') || (verb === 'stop' && !['cleaning', 'paused', 'returning'].includes(entity.state)) || (verb === 'return_to_base' && ['docked', 'returning'].includes(entity.state))) reject();
    service = verb;
  } else if (d === 'vacuum' && verb === 'fan' && features(entity, 32)) choose('fan_speed_list', 'fan_speed', 'set_fan_speed');
  else if (d === 'vacuum' && verb === 'rooms') {
    const map = roomMap(entity, context.entities, context.registry);
    if (!map || !Array.isArray(value) || !value.length || !value.every(id => map.rooms.some(r => r.id === id))) reject();
    const ids = map.rooms.filter(r => value.includes(r.id)).map(r => r.id);
    return { type: 'call_service', domain: 'notify', service: 'send_message', target: { entity_id: map.actionID }, service_data: { message: `'${ids.join(',')}'` } };
  } else if (['select', 'number', 'switch', 'button'].includes(d) && context.vacuumID) {
    const vacuum = context.entities.find(x => x.entity_id === context.vacuumID && domain(x) === 'vacuum' && available(x));
    if (!vacuum || !related(vacuum, context.entities, context.registry).some(x => x.entity_id === entity.entity_id)) reject();
    if (d === 'select' && verb === 'select') choose('options', 'option', 'select_option');
    else if (d === 'number' && verb === 'number' && Number.isFinite(entity.attributes.min) && Number.isFinite(entity.attributes.max)) { service = 'set_value'; data.value = number(entity.attributes.min, entity.attributes.max, Math.max(0.001, entity.attributes.step || 1)); }
    else if (d === 'button' && verb === 'press' && dockKeys.some(key => entity.entity_id.includes(key))) service = 'press';
    else reject();
  } else reject();
  return { type: 'call_service', domain: d, service, target: { entity_id: entity.entity_id }, service_data: data };
}
function publicEntity(e) {
  // Only display/control attributes cross into the renderer; camera tokens never do.
  const keys = ['friendly_name', 'supported_features', 'device_class', 'unit_of_measurement', 'temperature', 'current_temperature', 'target_temp_low', 'target_temp_high', 'target_temp_step', 'min_temp', 'max_temp', 'temperature_unit', 'hvac_modes', 'hvac_action', 'fan_modes', 'fan_mode', 'swing_modes', 'swing_mode', 'swing_horizontal_modes', 'swing_horizontal_mode', 'preset_modes', 'preset_mode', 'brightness', 'supported_color_modes', 'percentage', 'percentage_step', 'current_position', 'battery_level', 'fan_speed', 'fan_speed_list', 'options', 'min', 'max', 'step'];
  return { entity_id: e.entity_id, state: e.state, attributes: Object.fromEntries(keys.filter(k => e.attributes?.[k] !== undefined).map(k => [k, e.attributes[k]])) };
}
module.exports = { domain, available, features, options, safeCover, supported, on, related, vacuumOwners, roomMap, command, publicEntity, dockKeys, vacuumSection };
