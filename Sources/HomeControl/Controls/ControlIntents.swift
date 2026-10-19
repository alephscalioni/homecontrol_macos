import AppIntents
import Foundation
import HomeCore

// This file is compiled into both the host and the WidgetKit extension.
@available(macOS 26.0, *)
struct HomeFavoriteEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Favorite")
    static var defaultQuery = HomeFavoriteQuery()
    var id: String
    var name: String
    var room: String?
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: room.map { LocalizedStringResource(stringLiteral: $0) })
    }
    init(_ favorite: FavoriteControl) { id = favorite.id; name = favorite.name; room = favorite.room }
}

@available(macOS 26.0, *)
struct HomeFavoriteQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HomeFavoriteEntity] {
        let values = try ControlSharedStore.configured()?.read().favorites ?? []
        return identifiers.compactMap { id in values.first { $0.id == id }.map(HomeFavoriteEntity.init) }
    }
    func suggestedEntities() async throws -> [HomeFavoriteEntity] {
        try ControlSharedStore.configured()?.read().favorites.map(HomeFavoriteEntity.init) ?? []
    }
    func entities(matching string: String) async throws -> [HomeFavoriteEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) || ($0.room?.localizedCaseInsensitiveContains(string) ?? false) }
    }
}

@available(macOS 26.0, *)
struct PowerFavoriteOptions: DynamicOptionsProvider {
    func results() async throws -> [HomeFavoriteEntity] {
        try ControlSharedStore.configured()?.read().favorites.filter { $0.kind == .toggle }.map(HomeFavoriteEntity.init) ?? []
    }
}

@available(macOS 26.0, *)
struct SceneFavoriteOptions: DynamicOptionsProvider {
    func results() async throws -> [HomeFavoriteEntity] {
        try ControlSharedStore.configured()?.read().favorites.filter { $0.kind == .scene }.map(HomeFavoriteEntity.init) ?? []
    }
}

@available(macOS 26.0, *)
struct SelectPowerFavoriteIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a favorite switch"
    @Parameter(title: "Favorite", optionsProvider: PowerFavoriteOptions()) var favorite: HomeFavoriteEntity?
}

@available(macOS 26.0, *)
struct SelectSceneFavoriteIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a favorite scene"
    @Parameter(title: "Favorite", optionsProvider: SceneFavoriteOptions()) var favorite: HomeFavoriteEntity?
}

@available(macOS 14.0, *)
@MainActor
enum ControlIntentBridge {
    enum Action { case power(String, Bool), activate(String), temperature(String, Int), widgetPower(String, Bool), homeWidget(String, Bool?), refreshCamera(String), openCamera(String) }
    static var handler: ((Action) async throws -> Void)?
    static func perform(_ action: Action) async throws {
        guard let handler else { throw ControlIntentError.openApp }
        try await handler(action)
    }
}

enum ControlIntentError: LocalizedError {
    case openApp, missingFavorite, missingWidgetItem, unavailable, unsupported
    var errorDescription: String? {
        switch self {
        case .openApp: return L10n.text("Abra o HomeControl e tente novamente.")
        case .missingFavorite: return L10n.text("Este favorito mudou. Escolha-o novamente no Central de Controle.")
        case .missingWidgetItem: return L10n.text("Este item mudou. Edite o widget para escolhê-lo novamente.")
        case .unavailable: return L10n.text("Este aparelho está indisponível. Confira a conexão no HomeControl.")
        case .unsupported: return L10n.text("Abra o controle completo para ajustar este aparelho.")
        }
    }
}

// Execution stays in the host process without putting the HA token in the extension.
// The UI requires a connected host with validated registry metadata before enabling actions.
@available(macOS 26.0, *)
struct SetHomeFavoritePowerIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Set favorite power"
    static var isDiscoverable = false
    @Parameter(title: "Favorite") var favorite: HomeFavoriteEntity
    @Parameter(title: "On") var value: Bool
    init() {}
    init(favorite: HomeFavoriteEntity) { self.favorite = favorite }
    func perform() async throws -> some IntentResult {
        try await ControlIntentBridge.perform(.power(favorite.id, value))
        return .result()
    }
}

@available(macOS 26.0, *)
struct ActivateHomeFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate favorite"
    static var isDiscoverable = false
    @Parameter(title: "Favorite") var favorite: HomeFavoriteEntity
    init() {}
    init(favorite: HomeFavoriteEntity) { self.favorite = favorite }
    func perform() async throws -> some IntentResult {
        try await ControlIntentBridge.perform(.activate(favorite.id))
        return .result()
    }
}

@available(macOS 26.0, *)
@available(macOSApplicationExtension, unavailable)
extension SetHomeFavoritePowerIntent: ForegroundContinuableIntent {}

@available(macOS 26.0, *)
@available(macOSApplicationExtension, unavailable)
extension ActivateHomeFavoriteIntent: ForegroundContinuableIntent {}
