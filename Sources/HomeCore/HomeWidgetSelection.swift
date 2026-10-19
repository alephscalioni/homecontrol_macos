import Foundation

/// A widget keeps its own ordered selection. Missing items never select a replacement.
public enum HomeWidgetSelection {
    public static let limit = 4

    public static func supports(_ control: FavoriteControl) -> Bool {
        control.isCamera || control.kind == .toggle || control.kind == .scene || control.climate?.isSingleTarget == true
    }

    public static func typeName(for control: FavoriteControl) -> String {
        switch control.entityID.split(separator: ".").first {
        case "camera": return L10n.text("Câmera")
        case "vacuum": return L10n.text("Aspirador")
        case "light": return L10n.text("Luz")
        case "switch": return L10n.text("Interruptor ou tomada")
        case "fan": return L10n.text("Ventilador")
        case "climate": return L10n.text("Ar-condicionado")
        case "scene": return L10n.text("Cena")
        default: return L10n.text("Aparelho")
        }
    }

    public static func matches(_ control: FavoriteControl, query: String) -> Bool {
        let aliases: String
        switch control.entityID.split(separator: ".").first {
        case "camera": aliases = "camera cameras câmera câmeras vídeo video segurança security"
        case "vacuum": aliases = "aspirador aspiradores robo robô vacuum robot cleaner"
        case "light": aliases = "luz luzes iluminação light lights lighting"
        case "switch": aliases = "interruptor interruptores tomada tomadas switch switches outlet outlets"
        case "fan": aliases = "ventilador ventiladores fan fans"
        case "climate": aliases = "ar ar-condicionado climatização climate air conditioner"
        case "scene": aliases = "cena cenas scene scenes"
        default: aliases = ""
        }
        func normalized(_ value: String) -> String {
            value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        let terms = normalized(query).split(whereSeparator: \.isWhitespace)
        let text = normalized([control.name, control.room ?? "", control.entityID, typeName(for: control), aliases].joined(separator: " "))
        return terms.allSatisfy { text.contains($0) }
    }

    public static func identifiers(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return Array(ids.filter { !$0.isEmpty && seen.insert($0).inserted }.prefix(limit))
    }

    public static func select(_ id: String, replacing previousID: String?, in ids: [String], limit: Int = 4) -> [String] {
        let count = max(0, min(Self.limit, limit))
        var values = Array(identifiers(ids).prefix(count))
        guard !id.isEmpty, !values.contains(id) else { return values }
        if let previousID, let index = values.firstIndex(of: previousID) { values[index] = id }
        else if values.count < count { values.append(id) }
        return values
    }

    public static func options(in snapshot: FavoriteControlSnapshot) -> [FavoriteControl] {
        let values = snapshot.controls ?? (snapshot.favorites + (snapshot.climates ?? []))
        var seen = Set<String>()
        return values.filter { supports($0) && seen.insert($0.id).inserted }
    }

    public static func resolve(_ ids: [String], in snapshot: FavoriteControlSnapshot) -> [FavoriteControl?] {
        let values = options(in: snapshot)
        return identifiers(ids).map { id in values.first { $0.id == id } }
    }
}
