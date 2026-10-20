const entity = (entity_id, state, attributes) => ({ entity_id, state, attributes });
function demoHome() {
  const entities = [
    entity('climate.living_room', 'cool', { friendly_name: 'Ar da sala', temperature: 23, current_temperature: 25.5, temperature_unit: '°C', min_temp: 16, max_temp: 30, target_temp_step: 0.5, supported_features: 441, hvac_modes: ['off', 'cool', 'heat', 'dry', 'fan_only', 'auto'], fan_modes: ['auto', 'low', 'medium', 'high'], fan_mode: 'low', swing_modes: ['off', 'vertical', 'both'], swing_mode: 'vertical', preset_modes: ['none', 'eco', 'sleep'], preset_mode: 'none', hvac_action: 'cooling' }),
    entity('light.living_room', 'on', { friendly_name: 'Luz da sala', brightness: 190, supported_color_modes: ['brightness'] }),
    entity('switch.coffee', 'off', { friendly_name: 'Cafeteira' }),
    entity('fan.bedroom', 'off', { friendly_name: 'Ventilador', supported_features: 49, percentage: 40, percentage_step: 10 }),
    entity('cover.bedroom', 'open', { friendly_name: 'Cortina', supported_features: 15, current_position: 70, device_class: 'curtain' }),
    entity('sensor.temperature', '24.2', { friendly_name: 'Temperatura', unit_of_measurement: '°C', device_class: 'temperature' }),
    entity('sensor.energy', '1.8', { friendly_name: 'Consumo de hoje', unit_of_measurement: 'kWh', device_class: 'energy' }),
    entity('vacuum.robot', 'docked', { friendly_name: 'Aspirador', supported_features: 9020, battery_level: 92, fan_speed: 'standard', fan_speed_list: ['silent', 'standard', 'strong', 'turbo'] }),
    entity('select.robot_mop_water', 'medium', { friendly_name: 'Água no pano', options: ['low', 'medium', 'high'] }),
    entity('button.robot_start_mop_wash', 'unknown', { friendly_name: 'Lavar pano' }),
    entity('scene.good_night', '2026-10-19T20:00:00Z', { friendly_name: 'Boa noite' }),
    entity('light.bedside', 'unavailable', { friendly_name: 'Abajur', supported_color_modes: ['brightness'] })
  ];
  const areas = [{ area_id: 'living', name: 'Sala' }, { area_id: 'bedroom', name: 'Quarto' }, { area_id: 'kitchen', name: 'Cozinha' }];
  const devices = [{ id: 'robot-device', area_id: 'living', name: 'Aspirador' }];
  const registryEntities = entities.map(e => ({ entity_id: e.entity_id, area_id: /bedroom|bedside/.test(e.entity_id) ? 'bedroom' : /coffee/.test(e.entity_id) ? 'kitchen' : 'living', device_id: /robot/.test(e.entity_id) ? 'robot-device' : null }));
  return { entities, registry: { areas, devices, entities: registryEntities } };
}
module.exports = { demoHome };
