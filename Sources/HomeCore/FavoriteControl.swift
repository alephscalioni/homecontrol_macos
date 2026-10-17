import CryptoKit
import Foundation

public enum FavoriteControlKind: String, Codable, Sendable {
    case toggle, scene, open
}

public struct FavoriteControl: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let entityID: String
    public let name: String
    public let room: String?
    public let symbol: String
    public let isOn: Bool
    public let available: Bool
    public let kind: FavoriteControlKind
    public let climate: ClimateWidgetState?

    public init(entity: HAEntity, serverID: String, room: String? = nil) {
        // Escape the separator (and escape character) so arbitrary identities cannot collide.
        func escaped(_ value: String) -> String {
            value.replacingOccurrences(of: "%", with: "%25")
                .replacingOccurrences(of: "|", with: "%7C")
        }
        id = escaped(serverID) + "|" + escaped(entity.entityID)
        entityID = entity.entityID
        name = entity.name
        self.room = room
        isOn = entity.isOn
        available = entity.available
        climate = entity.domain == "climate" ? ClimateWidgetState(entity: entity) : nil
        if entity.domain == "scene" {
            kind = .scene
        } else if FavoritePower.supports(entity, isOn: true)
                    && FavoritePower.supports(entity, isOn: false) {
            kind = .toggle
        } else {
            kind = .open
        }
        switch entity.domain {
        case "light": symbol = "lightbulb.fill"
        case "switch": symbol = "power"
        case "fan": symbol = "fan.fill"
        case "climate": symbol = "thermometer"
        case "scene": symbol = "sparkles"
        case "sensor": symbol = "gauge.medium"
        case "binary_sensor": symbol = "sensor.fill"
        case "cover": symbol = "window.shade.closed"
        default: symbol = "square.grid.2x2"
        }
    }

    /// Hash only the canonical server identity; never retain an address or credentials.
    public static func serverID(for address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        var canonical = trimmed
        if var parts = URLComponents(string: trimmed),
           let scheme = parts.scheme?.lowercased(),
           ["http", "https"].contains(scheme), let host = parts.host, !host.isEmpty {
            parts.scheme = scheme
            parts.host = host.lowercased()
            parts.user = nil
            parts.password = nil
            parts.query = nil
            parts.fragment = nil
            if (scheme == "http" && parts.port == 80)
                || (scheme == "https" && parts.port == 443) {
                parts.port = nil
            }
            while parts.path.hasSuffix("/") { parts.path.removeLast() }
            canonical = parts.string ?? trimmed
        }
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

public struct FavoriteControlSnapshot: Codable, Equatable, Sendable {
    public let serverID: String
    public let favorites: [FavoriteControl]
    public let connected: Bool
    public let updatedAt: Date
    public let climates: [FavoriteControl]?
    public let controls: [FavoriteControl]?

    public init(serverID: String, favorites: [FavoriteControl], connected: Bool, updatedAt: Date = Date(), climates: [FavoriteControl]? = nil, controls: [FavoriteControl]? = nil, registryReady: Bool = true) {
        self.serverID = serverID
        self.favorites = registryReady ? favorites : []
        self.connected = connected && registryReady
        self.updatedAt = updatedAt
        self.climates = registryReady ? climates : []
        self.controls = registryReady ? controls : []
    }
}

private enum FavoritePower {
    static func supports(_ entity: HAEntity, isOn: Bool) -> Bool {
        if let value = entity.attributes["supported_features"] {
            guard let number = value.number, let mask = Int(exactly: number), mask >= 0 else { return false }
        }
        switch entity.domain {
        case "light", "switch": return true
        case "fan": return entity.supports(isOn ? 16 : 32)
        case "climate":
            return isOn ? entity.supports(256)
                : (entity.supports(128) || entity.options("hvac_modes").contains("off"))
        default: return false
        }
    }
}

extension ServiceCall {
    /// Set the desired power state without toggling or selecting an inferred HVAC mode.
    public static func setPower(_ entity: HAEntity, isOn: Bool) -> ServiceCall? {
        guard entity.available, entity.isOn != isOn,
              FavoritePower.supports(entity, isOn: isOn) else { return nil }
        if entity.domain == "climate", !isOn, !entity.supports(128) {
            return ServiceCall(entity, "set_hvac_mode", data: ["hvac_mode": .string("off")])
        }
        return ServiceCall(entity, isOn ? "turn_on" : "turn_off")
    }
}
