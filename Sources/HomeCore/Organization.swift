import Foundation

public enum EntityPurpose: String, Codable, CaseIterable, Identifiable, Sendable {
    case controls, environment, consumption, routines, maintenance, configuration, diagnostics, other
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .controls: return L10n.text("Controles")
        case .environment: return L10n.text("Ambiente e segurança")
        case .consumption: return L10n.text("Consumo")
        case .routines: return L10n.text("Horários e rotinas")
        case .maintenance: return L10n.text("Manutenção")
        case .configuration: return L10n.text("Configurações dos aparelhos")
        case .diagnostics: return L10n.text("Diagnóstico")
        case .other: return L10n.text("Outras leituras")
        }
    }
    public var icon: String {
        switch self {
        case .controls: return "switch.2"
        case .environment: return "thermometer.medium"
        case .consumption: return "bolt"
        case .routines: return "clock"
        case .maintenance: return "wrench.and.screwdriver"
        case .configuration: return "slider.horizontal.3"
        case .diagnostics: return "waveform.path.ecg"
        case .other: return "sensor"
        }
    }
    public var isEveryday: Bool { self == .controls || self == .environment }
}

public enum ConsumptionMetric: String, CaseIterable, Identifiable, Sendable {
    case energy, power, water, gas, electrical, other
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .energy: return L10n.text("Energia consumida")
        case .power: return L10n.text("Potência agora")
        case .water: return L10n.text("Água")
        case .gas: return L10n.text("Gás")
        case .electrical: return L10n.text("Medições elétricas")
        case .other: return L10n.text("Outras medições")
        }
    }
    public static func classify(_ entity: HAEntity) -> Self {
        guard entity.domain == "sensor" else { return .other }
        let deviceClass = entity.text("device_class") ?? ""
        let unit = entity.text("unit_of_measurement") ?? ""
        if ["energy", "energy_storage"].contains(deviceClass) || ["Wh", "kWh", "MWh", "GWh", "J", "kJ", "MJ", "GJ"].contains(unit) || entity.id.contains("_energy_") || entity.id.hasSuffix("_energia_total") { return .energy }
        if deviceClass == "power" || ["W", "kW", "MW"].contains(unit) { return .power }
        if deviceClass == "water" { return .water }
        if deviceClass == "gas" { return .gas }
        if ["current", "voltage", "apparent_power", "reactive_power", "power_factor", "frequency"].contains(deviceClass) || ["A", "mA", "V", "mV", "VA", "var", "Hz"].contains(unit) { return .electrical }
        return .other
    }
    /// Only supplied periods are described. Counters across devices or periods are never added.
    public static func period(_ entity: HAEntity, locale: Locale? = nil) -> String? {
        let id = entity.id
        if id.hasSuffix("_yesterday") { return L10n.text("Ontem", locale: locale) }
        if id.hasSuffix("_this_month") { return L10n.text("Este mês", locale: locale) }
        if id.hasSuffix("_last_month") { return L10n.text("Mês passado", locale: locale) }
        if id.hasSuffix("_today") { return L10n.text("Hoje", locale: locale) }
        if ["total", "total_increasing"].contains(entity.text("state_class") ?? "") || id.hasSuffix("_energia_total") { return L10n.text("Contador acumulado", locale: locale) }
        return nil
    }
}

public struct OrganizationPreferences: Codable, Equatable, Sendable {
    public var purposes: [String: EntityPurpose] = [:]
    public var hiddenIDs: Set<String> = []
    public init() {}
    public func isHidden(_ entity: HAEntity, entry: HARegistryEntity?) -> Bool {
        hiddenIDs.contains(entity.id) || entry?.hiddenBy != nil || entry?.disabledBy != nil
    }
}

public enum EntityOrganizer {
    public static func purpose(for entity: HAEntity, entry: HARegistryEntity? = nil, override: EntityPurpose? = nil) -> EntityPurpose {
        if let override { return override }
        let deviceClass = entity.text("device_class") ?? ""
        let id = entity.id
        let reading = ["sensor", "binary_sensor"].contains(entity.domain)
        if entry?.category == "config" { return .configuration }
        // Battery/filter life is useful maintenance even when the integration marks it diagnostic.
        if reading && (["battery", "battery_charging"].contains(deviceClass) || id.hasSuffix("_filter_remaining") || id.contains("_vida_util_") || id.hasSuffix("_bateria")) { return .maintenance }
        if entry?.category == "diagnostic" || entry?.platform == "backup" || entry?.platform == "sun" { return .diagnostics }
        if entity.domain == "switch" && (id.hasSuffix("_do_not_disturb") || id.hasSuffix("_nao_perturbe")) { return .configuration }
        if reading {
            if ConsumptionMetric.classify(entity) != .other { return .consumption }
            if deviceClass == "connectivity" || ["signal_strength", "data_rate", "data_size"].contains(deviceClass) || id.hasSuffix("_uptime") { return .diagnostics }
            if ["_next_alarm", "_next_reminder", "_next_timer", "_schedule_turn_on", "_schedule_turn_off", "_sleep_timer"].contains(where: { id.hasSuffix($0) }) { return .routines }
            if ["temperature", "humidity", "illuminance", "pressure", "atmospheric_pressure", "carbon_dioxide", "carbon_monoxide", "pm1", "pm10", "pm25", "volatile_organic_compounds", "volatile_organic_compounds_parts", "aqi", "moisture", "door", "window", "opening", "motion", "occupancy", "presence", "smoke", "gas", "safety", "problem", "heat", "cold", "tamper", "sound", "light"].contains(deviceClass) { return .environment }
            return .other
        }
        return .controls
    }
    public static func isGeneral(_ entity: HAEntity, entry: HARegistryEntity?) -> Bool {
        isGeneral(entityID: entity.id, entry: entry)
    }
    public static func isGeneral(entityID: String, entry: HARegistryEntity?) -> Bool {
        entityID.hasPrefix("scene.") || ["sun", "backup"].contains(entry?.platform ?? "")
    }
}
