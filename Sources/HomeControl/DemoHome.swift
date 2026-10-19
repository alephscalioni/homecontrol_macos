import Foundation
import HomeCore

enum DemoHome {
    static let entities: [HAEntity] = [
        HAEntity("vacuum.robot_demo", state: "docked", attributes: ["friendly_name": .string(L10n.text("Aspirador robô")), "supported_features": .number(12828)]),
        HAEntity("sensor.robot_demo_battery_level", state: "86", attributes: ["friendly_name": .string(L10n.text("Bateria")), "device_class": .string("battery"), "unit_of_measurement": .string("%")]),
        HAEntity("sensor.robot_demo_room_information", state: "{\"map_uid\":1,\"rooms\":[{\"id\":1,\"name\":\"Library\"},{\"id\":2,\"name\":\"Studio\"}]}", attributes: [:]),
        HAEntity("select.robot_demo_suction", state: "Standard", attributes: ["friendly_name": .string(L10n.text("Sucção")), "options": .strings(["Silent", "Standard", "Strong", "Turbo"])]),
        HAEntity("select.robot_demo_sweep_mop_type", state: "Vacuuming", attributes: ["friendly_name": .string(L10n.text("Modo de limpeza")), "options": .strings(["Vacuuming", "Mopping", "Vacuuming & Mopping"])]),
        HAEntity("select.robot_demo_mop_water_output_level", state: "Level 1", attributes: ["friendly_name": .string(L10n.text("Água no pano")), "options": .strings(["Off", "Level 1", "Level 2", "Level 3"])]),
        HAEntity("button.robot_demo_start_dust_arrest", state: "unknown", attributes: ["friendly_name": .string(L10n.text("Esvaziar pó"))]),
        HAEntity("notify.robot_demo_start_vacuum_room_sweep", state: "unknown", attributes: ["action params": .string("[Vacuum Room IDs(str)]")]),
        HAEntity("camera.entrada_demo", state: "idle", attributes: ["friendly_name": .string(L10n.text("Câmera da entrada"))]),
        HAEntity("camera.jardim_demo", state: "idle", attributes: ["friendly_name": .string(L10n.text("Câmera do jardim"))]),
        HAEntity("climate.quarto", state: "cool", attributes: [
            "friendly_name": .string(L10n.text("Ar-condicionado do quarto")), "temperature": .number(21),
            "current_temperature": .number(23), "temperature_unit": .string("°C"),
            "min_temp": .number(16), "max_temp": .number(32), "target_temp_step": .number(1),
            "hvac_modes": .strings(["off", "cool", "heat", "dry", "fan_only", "auto"]),
            "fan_modes": .strings(["auto", "low", "medium", "high"]), "fan_mode": .string("auto"),
            "preset_modes": .strings(["none", "eco", "sleep", "comfort"]), "preset_mode": .string("eco"),
            "swing_modes": .strings(["off", "vertical", "horizontal", "both"]), "swing_mode": .string("vertical"),
            "hvac_action": .string("cooling"), "supported_features": .number(441)
        ]),
        HAEntity("climate.sala", state: "off", attributes: [
            "friendly_name": .string(L10n.text("Ar-condicionado da sala")), "temperature": .number(24),
            "current_temperature": .number(25.5), "temperature_unit": .string("°C"),
            "min_temp": .number(16), "max_temp": .number(30), "target_temp_step": .number(0.5),
            "hvac_modes": .strings(["off", "cool", "heat", "auto"]), "supported_features": .number(385)
        ]),
        HAEntity("climate.termostato", state: "heat_cool", attributes: [
            "friendly_name": .string(L10n.text("Termostato da suíte")), "target_temp_low": .number(20), "target_temp_high": .number(24),
            "current_temperature": .number(22.5), "temperature_unit": .string("°C"),
            "min_temp": .number(16), "max_temp": .number(32), "target_temp_step": .number(0.5),
            "hvac_modes": .strings(["off", "heat_cool", "heat", "cool", "auto"]), "supported_features": .number(387)
        ]),
        HAEntity("light.sala", state: "on", attributes: ["friendly_name": .string(L10n.text("Luz da sala")), "brightness": .number(178), "supported_color_modes": .strings(["color_temp"]), "color_temp_kelvin": .number(3000), "min_color_temp_kelvin": .number(2200), "max_color_temp_kelvin": .number(6500)]),
        HAEntity("light.abajur", state: "on", attributes: ["friendly_name": .string(L10n.text("Abajur")), "brightness": .number(92), "supported_color_modes": .strings(["brightness"])]),
        HAEntity("light.cozinha", state: "off", attributes: ["friendly_name": .string(L10n.text("Luz da cozinha")), "supported_color_modes": .strings(["onoff"])]),
        HAEntity("switch.cafeteira", state: "off", attributes: ["friendly_name": .string(L10n.text("Cafeteira"))]),
        HAEntity("switch.escritorio", state: "on", attributes: ["friendly_name": .string(L10n.text("Tomada da bancada"))]),
        HAEntity("cover.sala", state: "open", attributes: ["friendly_name": .string(L10n.text("Cortina da sala")), "device_class": .string("curtain"), "current_position": .number(65), "supported_features": .number(15)]),
        HAEntity("fan.escritorio", state: "on", attributes: ["friendly_name": .string(L10n.text("Ventilador do escritório")), "percentage": .number(50), "percentage_step": .number(25), "oscillating": .bool(true), "preset_modes": .strings(["normal", "sleep"]), "preset_mode": .string("normal"), "supported_features": .number(59)]),
        HAEntity("scene.cinema", state: "2026-10-15T00:00:00Z", attributes: ["friendly_name": .string(L10n.text("Hora do cinema")), "icon": .string("mdi:movie-open")]),
        HAEntity("scene.boa_noite", state: "2026-10-15T00:00:00Z", attributes: ["friendly_name": .string(L10n.text("Boa noite"))]),
        HAEntity("scene.cheguei", state: "2026-10-15T00:00:00Z", attributes: ["friendly_name": .string(L10n.text("Cheguei em casa"))]),
        HAEntity("sensor.temperatura", state: "23.1", attributes: ["friendly_name": .string(L10n.text("Temperatura do quarto")), "unit_of_measurement": .string("°C"), "device_class": .string("temperature")]),
        HAEntity("sensor.umidade", state: "54", attributes: ["friendly_name": .string(L10n.text("Umidade do quarto")), "unit_of_measurement": .string("%"), "device_class": .string("humidity")]),
        HAEntity("binary_sensor.janela", state: "off", attributes: ["friendly_name": .string(L10n.text("Janela da sala")), "device_class": .string("window")])
    ]
    static let areas = [
        "camera.entrada_demo": L10n.text("Entrada"), "camera.jardim_demo": L10n.text("Jardim"),
        "climate.quarto": L10n.text("Quarto"), "climate.sala": L10n.text("Sala"), "light.sala": L10n.text("Sala"), "light.abajur": L10n.text("Quarto"),
        "light.cozinha": L10n.text("Cozinha"), "switch.cafeteira": L10n.text("Cozinha"), "switch.escritorio": L10n.text("Escritório"),
        "cover.sala": L10n.text("Sala"), "fan.escritorio": L10n.text("Escritório"), "sensor.temperatura": L10n.text("Quarto"), "sensor.umidade": L10n.text("Quarto"), "binary_sensor.janela": L10n.text("Sala"), "climate.termostato": L10n.text("Suíte")
    ]
    static var registry: HARegistry {
        let names = Set(areas.values).sorted()
        let rooms = names.map { name in
            HAArea(id: name.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR")).lowercased().replacingOccurrences(of: " ", with: "_"), name: name)
        }
        let ids = Dictionary(uniqueKeysWithValues: rooms.map { ($0.name, $0.id) })
        return HARegistry(areas: rooms, devices: [HADevice(id: "robot-demo", name: L10n.text("Aspirador robô"), areaID: ids[L10n.text("Cozinha")])], entities: entities.map {
            let robot = $0.id.contains("robot_demo")
            return HARegistryEntity(id: $0.id, deviceID: robot ? "robot-demo" : nil, areaID: robot ? ids[L10n.text("Cozinha")] : areas[$0.id].flatMap { ids[$0] }, platform: robot ? "xiaomi_home" : nil)
        })
    }
    static func apply(_ command: ServiceCall, to entity: inout HAEntity) {
        switch command.service {
        case "start": entity.state = "cleaning"
        case "pause": entity.state = "paused"
        case "stop": entity.state = "idle"
        case "return_to_base": entity.state = "returning"
        case "select_option": entity.state = command.data["option"]?.string ?? entity.state
        case "set_value": entity.state = command.data["value"]?.number.map { String($0) } ?? entity.state
        case "press", "send_message": entity.state = ISO8601DateFormatter().string(from: Date())
        case "turn_on":
            if entity.domain == "scene" { entity.state = "2026-10-15T12:00:00Z" }
            else { entity.state = entity.domain == "climate" ? "cool" : "on" }
        case "turn_off": entity.state = "off"
        case "set_hvac_mode": entity.state = command.data["hvac_mode"]?.string ?? entity.state
        case "set_fan_mode", "set_preset_mode", "set_swing_mode", "set_swing_horizontal_mode", "set_temperature":
            for (key, value) in command.data { entity.attributes[key] = value }
        case "set_percentage":
            entity.attributes["percentage"] = command.data["percentage"]
            entity.state = command.data["percentage"]?.number == 0 ? "off" : "on"
        case "oscillate": entity.attributes["oscillating"] = command.data["oscillating"]
        case "open_cover": entity.state = "open"; entity.attributes["current_position"] = .number(100)
        case "close_cover": entity.state = "closed"; entity.attributes["current_position"] = .number(0)
        case "set_cover_position":
            entity.attributes["current_position"] = command.data["position"]
            entity.state = command.data["position"]?.number == 0 ? "closed" : "open"
        default: break
        }
        if let percent = command.data["brightness_pct"]?.number { entity.attributes["brightness"] = .number(percent * 2.55) }
        if let kelvin = command.data["color_temp_kelvin"] { entity.attributes["color_temp_kelvin"] = kelvin }
    }
}
