import Foundation

/// A pure snapshot of the reported climate state and currently available commands.
public struct ClimateWidgetState: Codable, Equatable, Sendable {
    public let target: Double?
    public let current: Double?
    public let unit: String
    public let step: Double
    public let minimum: Double
    public let maximum: Double
    public let isSingleTarget: Bool
    public let canDecrease: Bool
    public let canIncrease: Bool
    public let canPowerOn: Bool
    public let canPowerOff: Bool
    public let mode: String
    public let action: String?

    public init(entity: HAEntity) {
        target = Self.finite(entity.number("temperature"))
        current = Self.finite(entity.number("current_temperature"))
        unit = entity.temperatureUnit
        let configuration = ClimateTemperatureConfiguration(entity)
        step = configuration?.step ?? (unit == "°F" ? 1 : 0.5)
        minimum = configuration?.minimum ?? (unit == "°F" ? 45 : 7)
        maximum = configuration?.maximum ?? (unit == "°F" ? 95 : 35)
        // Validate the feature mask before HAEntity's Double-to-Int conversion.
        let validFeatures = Self.hasValidFeatures(entity)
        isSingleTarget = entity.domain == "climate" && validFeatures
            && entity.supports(1) && !entity.usesTemperatureRange
        canDecrease = ServiceCall.adjustTemperature(entity, direction: -1) != nil
        canIncrease = ServiceCall.adjustTemperature(entity, direction: 1) != nil
        canPowerOn = entity.domain == "climate" && validFeatures
            && ServiceCall.setPower(entity, isOn: true) != nil
        canPowerOff = entity.domain == "climate" && validFeatures
            && ServiceCall.setPower(entity, isOn: false) != nil
        mode = entity.state
        action = entity.text("hvac_action")
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    fileprivate static func hasValidFeatures(_ entity: HAEntity) -> Bool {
        guard let value = entity.attributes["supported_features"] else { return true }
        guard let number = value.number, let mask = Int(exactly: number) else { return false }
        return mask >= 0
    }
}

/// Missing metadata uses HAEntity's unit-specific defaults. Invalid reported
/// metadata disables adjustments rather than passing unsafe bounds to its helper.
private struct ClimateTemperatureConfiguration {
    let step: Double
    let minimum: Double
    let maximum: Double

    init?(_ entity: HAEntity) {
        for key in ["min_temp", "max_temp", "target_temp_step"] {
            if let value = entity.attributes[key] {
                guard let number = value.number, number.isFinite else { return nil }
            }
        }
        let minimum = entity.number("min_temp") ?? (entity.temperatureUnit == "°F" ? 45 : 7)
        let maximum = entity.number("max_temp") ?? (entity.temperatureUnit == "°F" ? 95 : 35)
        let reportedStep = entity.number("target_temp_step") ?? (entity.temperatureUnit == "°F" ? 1 : 0.5)
        guard minimum <= maximum, reportedStep > 0,
              (maximum - minimum).isFinite, (minimum + 0.1).isFinite else { return nil }
        self.minimum = minimum
        self.maximum = max(minimum + 0.1, maximum)
        step = max(0.1, reportedStep)
    }
}

extension ServiceCall {
    /// Adjust only a single target, using the device step and existing wire format.
    public static func adjustTemperature(_ entity: HAEntity, direction: Int) -> ServiceCall? {
        guard direction == -1 || direction == 1,
              entity.domain == "climate", entity.available,
              ClimateWidgetState.hasValidFeatures(entity), entity.supports(1),
              !entity.usesTemperatureRange,
              let target = entity.number("temperature"), target.isFinite,
              let configuration = ClimateTemperatureConfiguration(entity),
              target >= configuration.minimum, target <= configuration.maximum else { return nil }
        let proposed = target + Double(direction) * configuration.step
        guard proposed.isFinite,
              ((proposed - configuration.minimum) / configuration.step).isFinite,
              let call = temperature(entity, value: proposed),
              let result = call.data["temperature"]?.number, result.isFinite,
              (direction == -1 ? result < target : result > target) else { return nil }
        return call
    }
}
