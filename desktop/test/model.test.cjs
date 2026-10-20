const { test } = require('node:test');
const assert = require('node:assert/strict');
const M = require('../src/model.cjs');
const { demoHome } = require('../src/demo.cjs');
const entity = (entity_id, state, attributes = {}) => ({ entity_id, state, attributes });

test('blocks unavailable devices, unsafe covers and unsupported climate actions', () => {
  assert.throws(() => M.command(entity('light.lamp', 'unavailable'), 'power'));
  assert.equal(M.supported(entity('cover.garage', 'closed', { device_class: 'garage' })), false);
  assert.throws(() => M.command(entity('cover.garage', 'closed', { device_class: 'garage', supported_features: 1 }), 'open'));
  assert.throws(() => M.command(entity('climate.ac', 'off', { hvac_modes: ['cool', 'off'] }), 'power'));
  assert.throws(() => M.command(entity('climate.ac', 'cool', { fan_modes: ['low'] }), 'fan', 'low'));
});
test('clamps and snaps temperatures, preserves climate ranges, validates choices', () => {
  const e = entity('climate.ac', 'cool', { supported_features: 1, min_temp: 16, max_temp: 30, target_temp_step: 0.5, hvac_modes: ['cool', 'off'] });
  assert.deepEqual(M.command(e, 'temperature', 24.2).service_data, { temperature: 24 });
  assert.deepEqual(M.command(e, 'temperature', 100).service_data, { temperature: 30 });
  assert.throws(() => M.command(e, 'temperature', NaN));
  assert.throws(() => M.command(e, 'hvac', 'invented'));
  const range = entity('climate.range', 'heat_cool', { supported_features: 3, min_temp: 10, max_temp: 35, target_temp_low: 20, target_temp_high: 26 });
  assert.throws(() => M.command(range, 'temperature', 22));
  assert.deepEqual(M.command(range, 'temperature-high', 18).service_data, { target_temp_low: 20, target_temp_high: 20 });
});
test('camera tokens and remote image URLs do not reach renderer snapshots', () => {
  const result = M.publicEntity(entity('camera.front', 'idle', { friendly_name: '<script>', access_token: 'secret', entity_picture: '/camera?token=secret', stream_source: 'rtsp://secret', supported_features: 2 }));
  assert.deepEqual(Object.keys(result.attributes).sort(), ['friendly_name', 'supported_features']);
  assert.equal(JSON.stringify(result).includes('secret'), false);
});
test('vacuum room IDs are isolated from HA areas and arbitrary notify actions', () => {
  const robot = entity('vacuum.robot', 'docked', { supported_features: 8192 });
  const map = entity('sensor.robot_room_information', JSON.stringify({ map_uid: 44, rooms: [{ id: 7, name: 'Sala' }, { id: 9, name: 'Quarto' }] }));
  const action = entity('notify.robot_start_vacuum_room_sweep', 'unknown', { 'action params': 'parameters[(str)]' });
  const context = { entities: [robot, map, action], registry: { entities: [robot,map,action].map(e => ({ entity_id: e.entity_id, device_id: 'robot', platform: 'xiaomi_home' })) } };
  const command = M.command(robot, 'rooms', ['7'], context);
  assert.equal(command.service_data.message, "'7'");
  assert.equal(command.domain, 'notify');
  assert.throws(() => M.command(robot, 'rooms', ['living-room-area'], context));
  context.registry.entities[2].device_id = 'other-robot';
  assert.throws(() => M.command(robot, 'rooms', ['7'], context));
});
test('groups Xiaomi vacuum settings and activities by their user-facing purpose', () => {
  const cases = [
    ['select.robot_cleaning_mode', 'Modo de limpeza', ['standard', 'mop'], 'cleaning'],
    ['select.robot_carpet_avoidance', 'Evitar tapetes', ['on', 'off'], 'navigation'],
    ['select.robot_no_disturb_schedule', 'Horário', ['on', 'off'], 'schedule'],
    ['button.robot_start_mop_wash', 'Lavar pano', [], 'dock'],
    ['sensor.robot_filter_life_level', 'Vida do filtro', [], 'maintenance'],
    ['sensor.robot_cleaning_progress', 'Progresso da limpeza', [], 'activity'],
    ['sensor.robot_room_information', 'Informação dos cômodos', [], 'advanced']
  ];
  for (const [entity_id, friendly_name, options, section] of cases) {
    assert.equal(M.vacuumSection(entity(entity_id, 'on', { friendly_name, options })), section, entity_id);
  }
});
test('consolidates Xiaomi activities under one robot and leaves ambiguous devices visible', () => {
  const entities = [
    entity('vacuum.xiaomi', 'docked'),
    entity('sensor.xiaomi_battery', '95'),
    entity('sensor.xiaomi_cleaning_time', '0'),
    entity('vacuum.other', 'docked')
  ];
  const registry = { entities: [
    { entity_id: 'vacuum.xiaomi', device_id: 'xiaomi-1' },
    { entity_id: 'sensor.xiaomi_battery', device_id: 'xiaomi-1' },
    { entity_id: 'sensor.xiaomi_cleaning_time', device_id: 'xiaomi-1' },
    { entity_id: 'vacuum.other', device_id: 'xiaomi-2' }
  ] };
  const owners = M.vacuumOwners(entities, registry);
  assert.equal(owners.get('sensor.xiaomi_battery'), 'vacuum.xiaomi');
  assert.equal(owners.get('sensor.xiaomi_cleaning_time'), 'vacuum.xiaomi');
  assert.deepEqual(M.related(entities[0], entities, registry).map(x => x.entity_id), ['sensor.xiaomi_battery', 'sensor.xiaomi_cleaning_time']);
  registry.entities[3].device_id = 'xiaomi-1';
  assert.equal(M.vacuumOwners(entities, registry).has('sensor.xiaomi_battery'), false);
});
test('dock commands only target allowed buttons on the selected robot', () => {
  const data = demoHome(); const robot = data.entities.find(e => e.entity_id === 'vacuum.robot');
  const wash = data.entities.find(e => e.entity_id === 'button.robot_start_mop_wash');
  const context = { ...data, vacuumID: robot.entity_id };
  assert.equal(M.command(wash, 'press', undefined, context).service, 'press');
  assert.throws(() => M.command(entity('button.robot_factory_reset', 'unknown'), 'press', undefined, context));
  assert.throws(() => M.command(wash, 'press', undefined, { ...context, vacuumID: 'vacuum.other' }));
});
test('scene activation never becomes a power toggle and sensors remain read-only', () => {
  assert.equal(M.command(entity('scene.night', 'unknown'), 'activate').service, 'turn_on');
  assert.throws(() => M.command(entity('scene.night', 'unknown'), 'power'));
  assert.throws(() => M.command(entity('sensor.temperature', '24'), 'power'));
});
