import Foundation

/// A visual interpretation of reported fan settings, never an electrical-power reading.
public struct ClimateAirflow: Equatable, Sendable {
    public let strength: Double
    public let sweepsHorizontally: Bool
    public var isRunning: Bool { strength > 0 }
    public static let stopped = ClimateAirflow(strength: 0, sweepsHorizontally: false)

    public init(entity: HAEntity) {
        guard entity.domain == "climate", entity.available, entity.isOn else {
            self = .stopped
            return
        }
        let raw = Self.normalized(entity.text("fan_mode") ?? "auto")
        let levels: [String: Double] = [
            "off": 0, "quiet": 0.18, "silent": 0.18, "silencioso": 0.18,
            "sleep": 0.2, "min": 0.2, "minimum": 0.2,
            "low": 0.28, "baixa": 0.28, "baixo": 0.28,
            "medium": 0.52, "mid": 0.52, "med": 0.52, "media": 0.52, "medio": 0.52,
            "high": 0.8, "alta": 0.8, "alto": 0.8,
            "turbo": 1, "boost": 1, "max": 1, "maximum": 1
        ]
        let reportedPercentage = entity.number("fan_percentage")
            ?? (raw.hasSuffix("%") ? Double(raw.dropLast()) : nil)
        if let value = reportedPercentage, value.isFinite {
            strength = min(1, max(0, value / 100))
        } else if let value = levels[raw] {
            strength = value
        } else if let value = Double(raw), value.isFinite {
            let modes = entity.options("fan_modes").compactMap(Double.init)
            if let maximum = modes.max(), maximum > 0, value >= 0 {
                strength = min(1, value / maximum)
            } else {
                strength = 0.45
            }
        } else {
            // Auto and integration-specific labels do not disclose actual fan power.
            strength = 0.45
        }
        let horizontal = Self.normalized(entity.text("swing_horizontal_mode") ?? "off")
        let swing = Self.normalized(entity.text("swing_mode") ?? "off")
        sweepsHorizontally = ["on", "auto", "swing", "horizontal", "both"].contains(horizontal)
            || ["horizontal", "both"].contains(swing)
    }

    private init(strength: Double, sweepsHorizontally: Bool) {
        self.strength = strength
        self.sweepsHorizontally = sweepsHorizontally
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
