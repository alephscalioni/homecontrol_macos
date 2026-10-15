import Foundation

/// Shared strings and number formatting for HomeCore and its clients.
public enum L10n {
    /// Uses the resource bundle's app/system language unless a locale is supplied.
    /// Explicit Portuguese locales share the Brazilian Portuguese translation.
    public static func text(_ key: String, locale: Locale? = nil) -> String {
        let english = localizedBundle("en")
        let fallback = english?.localizedString(forKey: key, value: key, table: nil) ?? key
        let bundle: Bundle
        if let locale {
            bundle = localizedBundle(locale.language.languageCode?.identifier == "pt" ? "pt-BR" : "en")
                ?? english ?? Bundle.module
        } else {
            bundle = Bundle.module
        }
        return bundle.localizedString(forKey: key, value: fallback, table: nil)
    }

    /// Templates use Foundation format specifiers such as %@ and %d.
    public static func format(_ key: String, _ arguments: CVarArg..., locale: Locale? = nil) -> String {
        String(format: text(key, locale: locale), locale: locale ?? .autoupdatingCurrent, arguments: arguments)
    }

    /// Numeric formatting follows the user's region independently of the app language.
    public static func number(_ value: Double, maximumFractionDigits: Int = 1, locale: Locale? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale ?? .autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = max(0, maximumFractionDigits)
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func localizedBundle(_ localization: String) -> Bundle? {
        Bundle.module.url(forResource: localization, withExtension: "lproj").flatMap { Bundle(url: $0) }
    }
}
