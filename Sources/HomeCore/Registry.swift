import Foundation

public struct HAArea: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let aliases: [String]
    public let icon: String?
    public init(id: String, name: String, aliases: [String] = [], icon: String? = nil) {
        self.id = id; self.name = name; self.aliases = aliases; self.icon = icon
    }
    init?(_ raw: JSONValue) {
        guard let id = raw["area_id"].string, let name = raw["name"].string else { return nil }
        self.init(id: id, name: name, aliases: raw["aliases"].array.compactMap(\.string), icon: raw["icon"].string)
    }
}

public struct HADevice: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let originalName: String?
    public let areaID: String?
    public let manufacturer: String?
    public let model: String?
    public init(id: String, name: String, originalName: String? = nil, areaID: String? = nil, manufacturer: String? = nil, model: String? = nil) {
        self.id = id; self.name = name; self.originalName = originalName; self.areaID = areaID
        self.manufacturer = manufacturer; self.model = model
    }
    init?(_ raw: JSONValue) {
        guard let id = raw["id"].string else { return nil }
        self.init(id: id, name: raw["name_by_user"].string ?? raw["name"].string ?? id,
                  originalName: raw["name"].string, areaID: raw["area_id"].string,
                  manufacturer: raw["manufacturer"].string, model: raw["model"].string)
    }
}

public struct HARegistryEntity: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let originalName: String?
    public let deviceID: String?
    public let areaID: String?
    public let category: String?
    public let platform: String?
    public let hiddenBy: String?
    public let disabledBy: String?
    public init(id: String, name: String? = nil, originalName: String? = nil, deviceID: String? = nil,
                areaID: String? = nil, category: String? = nil, platform: String? = nil,
                hiddenBy: String? = nil, disabledBy: String? = nil) {
        self.id = id; self.name = name; self.originalName = originalName; self.deviceID = deviceID
        self.areaID = areaID; self.category = category; self.platform = platform
        self.hiddenBy = hiddenBy; self.disabledBy = disabledBy
    }
    init?(_ raw: JSONValue) {
        guard let id = raw["entity_id"].string else { return nil }
        self.init(id: id, name: raw["name"].string, originalName: raw["original_name"].string,
                  deviceID: raw["device_id"].string, areaID: raw["area_id"].string,
                  category: raw["entity_category"].string, platform: raw["platform"].string,
                  hiddenBy: raw["hidden_by"].string, disabledBy: raw["disabled_by"].string)
    }
}

public enum RoomScope: Equatable, Sendable {
    case all, area(String), general, unassigned
}

public struct HARegistry: Codable, Equatable, Sendable {
    public var areas: [HAArea]
    public var devices: [HADevice]
    public var entities: [HARegistryEntity]
    public var friendlyNames: [String: String]
    public init(areas: [HAArea] = [], devices: [HADevice] = [], entities: [HARegistryEntity] = [], friendlyNames: [String: String] = [:]) {
        self.areas = areas; self.devices = devices; self.entities = entities; self.friendlyNames = friendlyNames
    }
    public func effectiveAreaID(for entityID: String) -> String? {
        guard let entity = entities.first(where: { $0.id == entityID }) else { return nil }
        let id = entity.areaID ?? entity.deviceID.flatMap { deviceID in devices.first { $0.id == deviceID }?.areaID }
        return id.flatMap { areaID in areas.contains { $0.id == areaID } ? areaID : nil }
    }
    public func matches(_ entityID: String, scope: RoomScope) -> Bool {
        switch scope {
        case .all: return true
        case .area(let id): return effectiveAreaID(for: entityID) == id
        case .general: return effectiveAreaID(for: entityID) == nil && EntityOrganizer.isGeneral(entityID: entityID, entry: entities.first { $0.id == entityID })
        case .unassigned: return effectiveAreaID(for: entityID) == nil && !EntityOrganizer.isGeneral(entityID: entityID, entry: entities.first { $0.id == entityID })
        }
    }
    public var areaIDsByEntity: [String: String] {
        let validAreas = Set(areas.map(\.id))
        let deviceAreas = Dictionary(devices.compactMap { device in device.areaID.map { (device.id, $0) } }, uniquingKeysWith: { first, _ in first })
        var result: [String: String] = [:]
        for entity in entities {
            if let areaID = entity.areaID ?? entity.deviceID.flatMap({ deviceAreas[$0] }), validAreas.contains(areaID) {
                result[entity.id] = areaID
            }
        }
        return result
    }
    public var entityAreaNames: [String: String] {
        let names = Dictionary(areas.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return areaIDsByEntity.compactMapValues { names[$0] }
    }
    @MainActor public static func fetch(using client: HomeAssistantClient, friendlyNames: [String: String] = [:]) async throws -> HARegistry {
        async let areas = client.request(["type": .string("config/area_registry/list")])
        async let devices = client.request(["type": .string("config/device_registry/list")])
        async let entities = client.request(["type": .string("config/entity_registry/list")])
        let (a, d, e) = try await (areas, devices, entities)
        guard case .array = a, case .array = d, case .array = e else { throw HAError.malformed }
        return HARegistry(areas: a.array.compactMap(HAArea.init), devices: d.array.compactMap(HADevice.init),
                          entities: e.array.compactMap(HARegistryEntity.init), friendlyNames: friendlyNames)
    }
}

public struct AreaAssignment: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case device, entity }
    public let kind: Kind
    public let id: String
    public let name: String
    public let previousAreaID: String?
    public let areaID: String?
    public let reason: String
    public init(kind: Kind, id: String, name: String, previousAreaID: String?, areaID: String?, reason: String) {
        self.kind = kind; self.id = id; self.name = name; self.previousAreaID = previousAreaID; self.areaID = areaID; self.reason = reason
    }
    public var payload: [String: JSONValue] {
        ["type": .string(kind == .device ? "config/device_registry/update" : "config/entity_registry/update"),
         kind == .device ? "device_id" : "entity_id": .string(id), "area_id": areaID.map(JSONValue.string) ?? .null]
    }
    public var reversed: AreaAssignment {
        AreaAssignment(kind: kind, id: id, name: name, previousAreaID: areaID, areaID: previousAreaID, reason: "Reverter: \(reason)")
    }
}

public struct AreaAssignmentPlan: Codable, Sendable {
    public let server: String
    public let changes: [AreaAssignment]
    public init(server: String, changes: [AreaAssignment]) { self.server = server; self.changes = changes }
    public func validate(against registry: HARegistry) throws {
        var seen = Set<String>()
        for change in changes {
            guard seen.insert("\(change.kind.rawValue):\(change.id)").inserted else {
                throw HAError.server("O plano repete o item \(change.name).")
            }
            if let areaID = change.areaID, !registry.areas.contains(where: { $0.id == areaID }) {
                throw HAError.server("O cômodo de destino de \(change.name) não existe mais.")
            }
            let current: String?
            switch change.kind {
            case .device:
                guard let device = registry.devices.first(where: { $0.id == change.id }) else { throw HAError.server("Dispositivo removido: \(change.name).") }
                current = device.areaID
            case .entity:
                guard let entity = registry.entities.first(where: { $0.id == change.id }) else { throw HAError.server("Entidade removida: \(change.name).") }
                current = entity.areaID
            }
            guard current == change.previousAreaID else {
                throw HAError.server("O cômodo de \(change.name) mudou depois do inventário. Atualize o plano antes de aplicar.")
            }
        }
    }
}
