import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    public init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() { self = .null }
        else if let value = try? box.decode(Bool.self) { self = .bool(value) }
        else if let value = try? box.decode(Double.self) { self = .number(value) }
        else if let value = try? box.decode(String.self) { self = .string(value) }
        else if let value = try? box.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try box.decode([JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .string(let value): try box.encode(value)
        case .number(let value): try box.encode(value)
        case .bool(let value): try box.encode(value)
        case .object(let value): try box.encode(value)
        case .array(let value): try box.encode(value)
        case .null: try box.encodeNil()
        }
    }
    public var string: String? { if case .string(let v) = self { return v }; return nil }
    public var number: Double? { if case .number(let v) = self { return v }; return nil }
    public var bool: Bool? { if case .bool(let v) = self { return v }; return nil }
    public var array: [JSONValue] { if case .array(let v) = self { return v }; return [] }
    public var object: [String: JSONValue] { if case .object(let v) = self { return v }; return [:] }
    public subscript(_ key: String) -> JSONValue { object[key] ?? .null }
    public static func strings(_ values: [String]) -> JSONValue { .array(values.map(Self.string)) }
}

public struct HAEntity: Codable, Identifiable, Equatable, Sendable {
    public var entityID: String
    public var state: String
    public var attributes: [String: JSONValue]
    public var lastUpdated: String?
    enum CodingKeys: String, CodingKey {
        case entityID = "entity_id", state, attributes, lastUpdated = "last_updated"
    }
    public init(_ id: String, state: String, attributes: [String: JSONValue], lastUpdated: String? = nil) {
        entityID = id; self.state = state; self.attributes = attributes; self.lastUpdated = lastUpdated
    }
    public var id: String { entityID }
    public var domain: String { String(entityID.split(separator: ".").first ?? "") }
    public var name: String { attributes["friendly_name"]?.string ?? entityID }
    public var available: Bool {
        state != "unavailable" && (state != "unknown" || ["button", "notify"].contains(domain))
    }
    public var isOn: Bool { available && !["off", "closed", "standby"].contains(state) }
    public func number(_ key: String) -> Double? { attributes[key]?.number }
    public func text(_ key: String) -> String? { attributes[key]?.string }
    public func options(_ key: String) -> [String] { attributes[key]?.array.compactMap(\.string) ?? [] }
    public func supports(_ flag: Int) -> Bool { (Int(number("supported_features") ?? 0) & flag) != 0 }
    public var temperatureUnit: String { text("temperature_unit") ?? "°C" }
    public var temperatureBounds: ClosedRange<Double> {
        let low = number("min_temp") ?? (temperatureUnit == "°F" ? 45 : 7)
        let high = number("max_temp") ?? (temperatureUnit == "°F" ? 95 : 35)
        return low...max(low + 0.1, high)
    }
    public var temperatureStep: Double { max(0.1, number("target_temp_step") ?? (temperatureUnit == "°F" ? 1 : 0.5)) }
    public var usesTemperatureRange: Bool { supports(2) && (["heat_cool", "auto"].contains(state) || !supports(1)) }
    public var supportsBrightness: Bool {
        domain == "light" && options("supported_color_modes").contains { !["onoff", "unknown"].contains($0) }
    }
    public var isSafeCover: Bool {
        domain == "cover" && !["garage", "gate", "door"].contains(text("device_class") ?? "")
    }
    public var isSupported: Bool {
        ["climate", "light", "switch", "fan", "scene", "sensor", "binary_sensor", "camera", "vacuum"].contains(domain) || isSafeCover
    }
    public var timestamp: Date? { Self.date(lastUpdated) }
    public static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

public struct ServiceCall: Equatable, Sendable {
    public let domain: String
    public let service: String
    public let entityID: String
    public let data: [String: JSONValue]
    public init(_ entity: HAEntity, _ service: String, data: [String: JSONValue] = [:]) {
        domain = entity.domain; self.service = service; entityID = entity.id; self.data = data
    }
    public var payload: [String: JSONValue] {
        ["type": .string("call_service"), "domain": .string(domain), "service": .string(service),
         "target": .object(["entity_id": .string(entityID)]), "service_data": .object(data)]
    }
    public static func power(_ entity: HAEntity) -> ServiceCall? {
        guard entity.available else { return nil }
        switch entity.domain {
        case "light", "switch": return ServiceCall(entity, entity.isOn ? "turn_off" : "turn_on")
        case "fan":
            guard entity.supports(entity.isOn ? 32 : 16) else { return nil }
            return ServiceCall(entity, entity.isOn ? "turn_off" : "turn_on")
        case "climate":
            if entity.isOn {
                if entity.supports(128) { return ServiceCall(entity, "turn_off") }
                if entity.options("hvac_modes").contains("off") {
                    return ServiceCall(entity, "set_hvac_mode", data: ["hvac_mode": .string("off")])
                }
            } else {
                if entity.supports(256) { return ServiceCall(entity, "turn_on") }
                // If turn_on is unsupported, the user chooses the intended mode explicitly.
            }
            return nil
        default: return nil
        }
    }
    public static func temperature(_ entity: HAEntity, value: Double, high: Bool? = nil) -> ServiceCall? {
        guard entity.domain == "climate", value.isFinite else { return nil }
        let bounds = entity.temperatureBounds
        let step = entity.temperatureStep
        let snapped = min(bounds.upperBound, max(bounds.lowerBound,
            bounds.lowerBound + ((value - bounds.lowerBound) / step).rounded() * step))
        if entity.usesTemperatureRange {
            guard let high,
                  let lowValue = entity.number("target_temp_low"),
                  let highValue = entity.number("target_temp_high") else { return nil }
            let low = high ? lowValue : min(snapped, highValue)
            let upper = high ? max(snapped, lowValue) : highValue
            return ServiceCall(entity, "set_temperature", data: ["target_temp_low": .number(low), "target_temp_high": .number(upper)])
        }
        guard entity.supports(1) else { return nil }
        return ServiceCall(entity, "set_temperature", data: ["temperature": .number(snapped)])
    }
}

public enum ServerAddress {
    public static func normalize(_ input: String) throws -> URL {
        guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil else { throw HAError.invalidAddress }
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        parts.scheme = parts.scheme?.lowercased()
        guard let url = parts.url else { throw HAError.invalidAddress }
        return url
    }
    public static func websocket(_ base: URL) -> URL {
        var parts = URLComponents(url: base.appendingPathComponent("api/websocket"), resolvingAgainstBaseURL: false)!
        parts.scheme = base.scheme == "https" ? "wss" : "ws"
        return parts.url!
    }
}

public enum HAError: LocalizedError, Equatable {
    case invalidAddress, invalidToken, disconnected, timeout, server(String), malformed
    public var errorDescription: String? {
        switch self {
        case .invalidAddress: return L10n.text("Use o endereço completo, como http://homeassistant.local:8123, sem usuário, senha ou parâmetros na URL.")
        case .invalidToken: return L10n.text("O Home Assistant recusou o token. Gere outro em Perfil → Segurança → Tokens de acesso de longa duração.")
        case .disconnected: return L10n.text("Sem conexão com o Home Assistant. Verifique a rede e tente novamente.")
        case .timeout: return L10n.text("O Home Assistant não respondeu a tempo. Confira o estado do aparelho antes de repetir o comando.")
        case .server(let message): return message
        case .malformed: return L10n.text("A resposta do Home Assistant não pôde ser lida. Tente reconectar.")
        }
    }
}
