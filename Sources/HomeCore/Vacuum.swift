import Foundation

/// Standard HA vacuum actions; never treat a robot as an on/off switch.
public enum VacuumAction: String, CaseIterable, Sendable {
    case start, pause, stop, returnToBase = "return_to_base", locate
    var feature: Int {
        switch self {
        case .start: return 8192
        case .pause: return 4
        case .stop: return 8
        case .returnToBase: return 16
        case .locate: return 512
        }
    }
    public func command(for entity: HAEntity) -> ServiceCall? {
        guard entity.domain == "vacuum", entity.available,
              let flags = entity.number("supported_features"), flags.isFinite,
              flags >= 0, flags < Double(Int.max), flags.rounded(.towardZero) == flags,
              Int(flags) & feature != 0 else { return nil }
        switch self {
        case .start: guard !["cleaning", "returning"].contains(entity.state) else { return nil }
        case .pause: guard entity.state == "cleaning" else { return nil }
        case .stop: guard ["cleaning", "paused", "returning"].contains(entity.state) else { return nil }
        case .returnToBase: guard !["docked", "returning"].contains(entity.state) else { return nil }
        case .locate: break
        }
        return ServiceCall(entity, rawValue)
    }
}

public enum VacuumSection: String, CaseIterable, Identifiable, Sendable {
    case cleaning, dock, navigation, schedule, maintenance, activity, advanced
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .cleaning: return L10n.text("Ajustes de limpeza")
        case .dock: return L10n.text("Base e pano")
        case .navigation: return L10n.text("Tapetes e navegação")
        case .schedule: return L10n.text("Horários e som")
        case .maintenance: return L10n.text("Manutenção")
        case .activity: return L10n.text("Dados da limpeza")
        case .advanced: return L10n.text("Avançado")
        }
    }
    public var icon: String {
        switch self {
        case .cleaning: return "slider.horizontal.3"
        case .dock: return "drop"
        case .navigation: return "point.topleft.down.to.point.bottomright.curvepath"
        case .schedule: return "clock"
        case .maintenance: return "wrench.and.screwdriver"
        case .activity: return "list.bullet.rectangle"
        case .advanced: return "gearshape"
        }
    }
}

public enum VacuumOrganization {
    private static let protocolSuffix = try! NSRegularExpression(pattern: "_[pae]_[0-9]+_[0-9]+$")
    /// Only unambiguous registry device IDs join entities. Renames never change membership.
    public static func owners(entities: [HAEntity], entries: [String: HARegistryEntity]) -> [String: String] {
        let robots = Dictionary(grouping: entities.filter { $0.domain == "vacuum" && entries[$0.id]?.deviceID != nil }, by: { entries[$0.id]!.deviceID! })
        var result: [String: String] = [:]
        let domains: Set<String> = ["sensor", "binary_sensor", "switch", "select", "number", "button", "text", "event", "notify"]
        for entity in entities where domains.contains(entity.domain) {
            if let device = entries[entity.id]?.deviceID, let matches = robots[device], matches.count == 1 {
                result[entity.id] = matches[0].id
            }
        }
        return result
    }

    public static func isConsolidated(_ entity: HAEntity, owners: [String: String], visibleIDs: Set<String>, preferences: OrganizationPreferences) -> Bool {
        guard let owner = owners[entity.id], visibleIDs.contains(owner) else { return false }
        return preferences.purposes[entity.id] == nil
    }

    /// MIoT property/action suffixes contain protocol indexes, not user-facing meaning.
    public static func key(_ entity: HAEntity) -> String {
        protocolSuffix.stringByReplacingMatches(in: entity.id, range: NSRange(entity.id.startIndex..., in: entity.id), withTemplate: "").lowercased()
    }
    public static func has(_ entity: HAEntity, _ suffixes: [String]) -> Bool {
        let value = key(entity)
        return suffixes.contains { value.hasSuffix("_" + $0) || value.hasSuffix("." + $0) }
    }
    private static func contains(_ entity: HAEntity, _ terms: [String]) -> Bool {
        let value = key(entity) + " " + entity.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return terms.contains { value.contains($0) }
    }
    public static func isPrimarySetting(_ entity: HAEntity) -> Bool {
        entity.domain == "select" && !contains(entity, ["carpet", "avoidance", "wash", "dry", "dust_arrest", "worry_free"]) &&
            (isSuctionSetting(entity) || has(entity, ["sweep_mop_type", "cleaning_mode", "clean_times", "mop_water_output_level", "water_level", "water_output_for_mopping"]))
    }
    public static func isSuctionSetting(_ entity: HAEntity) -> Bool {
        guard entity.domain == "select" else { return false }
        if has(entity, ["suction", "suction_level", "suction_power", "fan_speed"]) { return true }
        let options = Set(entity.options("options").map { $0.lowercased() })
        let speeds: Set<String> = ["silent", "quiet", "gentle", "standard", "normal", "strong", "turbo", "max", "low", "medium", "high"]
        return has(entity, ["mode"]) && !contains(entity, ["carpet", "wash", "worry_free"]) && options.count >= 2 && options.isSubset(of: speeds)
    }
    public static func isBusy(robotID: String, owners: [String: String], pendingIDs: Set<String>) -> Bool {
        pendingIDs.contains(robotID) || pendingIDs.contains { owners[$0] == robotID }
    }
    public static func section(for entity: HAEntity, entry: HARegistryEntity? = nil, override: EntityPurpose? = nil) -> VacuumSection {
        if let override {
            switch override {
            case .controls, .configuration: return .cleaning
            case .routines: return .schedule
            case .maintenance: return .maintenance
            case .environment, .consumption, .other: return .activity
            case .diagnostics: return .advanced
            }
        }
        // Raw action, map, video and protocol fields remain available in HA, never editable here.
        if VacuumDockAction.allCases.contains(where: { $0.matches(entity) }) { return .dock }
        if ["button", "text", "event", "notify"].contains(entity.domain) { return .advanced }
        if isPrimarySetting(entity) { return .cleaning }
        if contains(entity, ["life_level", "left_time", "left_level", "remaining", "vida_util", "battery", "bateria", "tank_status", "charging_state", "device_fault"]) && !contains(entity, ["dry_left_time"]) { return .maintenance }
        if contains(entity, ["map_", "_map", "trajectory", "position", "firmware", "frameware", "download", "_voice", "stream", "video", "flash_light", "_info", "_result", "fault_ids", "zone_ids", "room_information", "_config", "_cfg", "_dialog", "_object", "_notice", "updata", "_sill", "remote", "locked", "control_lock"]) { return .advanced }
        if contains(entity, ["no_disturb", "do_not_disturb", "nao_perturbe", "volume", "schedule", "order_clean", "enable_time_period", "sleep", "alarm"]) { return .schedule }
        if contains(entity, ["carpet", "tapete", "avoidance", "detection", "sweep_route", "edge_", "outer_swing", "outswing"]) { return .navigation }
        if contains(entity, ["mop_wash", "washing_mop", "wash_mop", "dry", "dust_arrest", "auto_water", "detergent", "cut_hair", "water_change", "mop_auto_lift", "repeat_wash"]) { return .dock }
        if ["select", "number", "switch"].contains(entity.domain) { return entry?.category == "diagnostic" ? .advanced : .cleaning }
        if contains(entity, ["cleaning", "clean_time", "clean_area", "sweep_mop_status", "mop_status", "statistical"]) { return .activity }
        return .advanced
    }
    public static func purpose(for entity: HAEntity, entry: HARegistryEntity? = nil, override: EntityPurpose? = nil) -> EntityPurpose {
        if let override { return override }
        switch section(for: entity, entry: entry) {
        case .cleaning, .dock, .navigation: return .configuration
        case .schedule: return .routines
        case .maintenance: return .maintenance
        case .activity: return .other
        case .advanced: return .diagnostics
        }
    }
    public static func shortName(_ entity: HAEntity, deviceName: String?) -> String {
        var name = entity.name
        if let deviceName, !deviceName.isEmpty {
            while name.lowercased().hasPrefix(deviceName.lowercased()) {
                name = String(name.dropFirst(deviceName.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        for prefix in ["Robot Cleaner ", "Battery ", "Vacuum Map ", "Brush Cleaner ", "Filter ", "Mop ", "Voice Management ", "Detergent Management ", "Dust Bag ", "Stream Management ", "Alarm ", "No Disturb "] {
            if name.hasPrefix(prefix) { name = String(name.dropFirst(prefix.count)) }
        }
        return name.isEmpty ? entity.name : name
    }

    /// Only ordinary scalar settings are editable; encoded schedules/protocol integers are read-only.
    public static func numberBounds(_ entity: HAEntity) -> ClosedRange<Double>? {
        guard entity.domain == "number", let low = entity.number("min"), let high = entity.number("max"),
              let step = entity.number("step"), low.isFinite, high.isFinite, step.isFinite,
              low < high, step > 0, (high - low) / step <= 1000 else { return nil }
        return low...high
    }
    public static func setting(_ entity: HAEntity, option: String) -> ServiceCall? {
        guard entity.available, entity.domain == "select", entity.options("options").contains(option) else { return nil }
        return ServiceCall(entity, "select_option", data: ["option": .string(option)])
    }
    public static func suction(_ entity: HAEntity, speed: String) -> ServiceCall? {
        guard entity.domain == "vacuum", entity.available, entity.options("fan_speed_list").contains(speed),
              let flags = entity.number("supported_features"), flags.isFinite, flags >= 0, flags < Double(Int.max), flags.rounded() == flags,
              Int(flags) & 32 != 0 else { return nil }
        return ServiceCall(entity, "set_fan_speed", data: ["fan_speed": .string(speed)])
    }
    public static func setting(_ entity: HAEntity, number: Double) -> ServiceCall? {
        guard entity.available, number.isFinite, let bounds = numberBounds(entity), let step = entity.number("step") else { return nil }
        let snapped = bounds.lowerBound + ((number - bounds.lowerBound) / step).rounded() * step
        return ServiceCall(entity, "set_value", data: ["value": .number(min(bounds.upperBound, max(bounds.lowerBound, snapped)))])
    }
}

public struct VacuumMapRoom: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
}

public struct VacuumRoomMap: Equatable, Sendable {
    public let mapID: String
    public let rooms: [VacuumMapRoom]
    /// The vacuum's map IDs are independent of Home Assistant area IDs.
    public init?(entity: HAEntity) {
        guard entity.domain == "sensor", VacuumOrganization.has(entity, ["room_information"]),
              let data = entity.state.data(using: .utf8), data.count <= 256_000,
              let value = try? JSONDecoder().decode(JSONValue.self, from: data),
              let mapID = Self.identifier(value["map_uid"]), !value["rooms"].array.isEmpty else { return nil }
        var seen = Set<String>()
        let rooms = value["rooms"].array.prefix(100).compactMap { raw -> VacuumMapRoom? in
            guard let id = Self.identifier(raw["id"]), seen.insert(id).inserted else { return nil }
            let name = (raw["name"].string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return VacuumMapRoom(id: id, name: String(name.prefix(100)))
        }
        guard !rooms.isEmpty else { return nil }
        self.mapID = mapID; self.rooms = rooms
    }
    private static func identifier(_ value: JSONValue) -> String? {
        if let number = value.number, number.isFinite, number >= 0, number <= Double(Int32.max), number.rounded() == number { return String(Int(number)) }
        if let text = value.string, !text.isEmpty, text.count <= 10, text.allSatisfy(\.isNumber), let number = Int32(text), number >= 0 { return String(number) }
        return nil
    }
    /// A YAML-quoted scalar preserves the one-string MIoT input, including a single room.
    public func command(selectedIDs: Set<String>, action: HAEntity, entry: HARegistryEntity?) -> ServiceCall? {
        guard action.domain == "notify", action.available, entry?.platform == "xiaomi_home",
              VacuumOrganization.has(action, ["start_vacuum_room_sweep"]),
              let schema = action.text("action params"), schema.hasSuffix("(str)]"), schema.filter({ $0 == "(" }).count == 1,
              !selectedIDs.isEmpty, selectedIDs.isSubset(of: Set(rooms.map(\.id))) else { return nil }
        let ids = rooms.filter { selectedIDs.contains($0.id) }.map(\.id).joined(separator: ",")
        return ServiceCall(action, "send_message", data: ["message": .string("'" + ids + "'")])
    }
}

/// Explicit allowlist of ordinary dock operations. Map resets, remote driving and credentials stay in HA.
public enum VacuumDockAction: String, CaseIterable, Sendable {
    case emptyDust, washMop, stopWash, dryMop, stopDry, cleanBase, stopCleanBase, emptyWater
    public var title: String {
        switch self {
        case .emptyDust: return L10n.text("Esvaziar pó")
        case .washMop: return L10n.text("Lavar pano")
        case .stopWash: return L10n.text("Parar lavagem")
        case .dryMop: return L10n.text("Secar pano")
        case .stopDry: return L10n.text("Parar secagem")
        case .cleanBase: return L10n.text("Limpar base")
        case .stopCleanBase: return L10n.text("Parar limpeza da base")
        case .emptyWater: return L10n.text("Esvaziar água da base")
        }
    }
    public var icon: String {
        switch self {
        case .emptyDust: return "bin.xmark"
        case .washMop, .emptyWater: return "drop"
        case .dryMop: return "wind"
        case .cleanBase: return "sparkles"
        case .stopWash, .stopDry, .stopCleanBase: return "stop.fill"
        }
    }
    public func matches(_ entity: HAEntity) -> Bool {
        guard entity.domain == "button" else { return false }
        let keys: [String]
        switch self {
        case .emptyDust: keys = ["start_dust_arrest"]
        case .washMop: keys = ["start_mop_wash"]
        case .stopWash: keys = ["stop_mop_wash"]
        case .dryMop: keys = ["start_dry"]
        case .stopDry: keys = ["stop_dry"]
        case .cleanBase: keys = ["start_self_cleaning_of_the_station", "start_base_station_cleaning"]
        case .stopCleanBase: keys = ["stop_self_cleaning_of_the_station"]
        case .emptyWater: keys = ["empty_base_station_water_tank"]
        }
        return VacuumOrganization.has(entity, keys)
    }
    public func command(for entity: HAEntity) -> ServiceCall? {
        guard matches(entity), entity.available else { return nil }
        return ServiceCall(entity, "press")
    }
}
