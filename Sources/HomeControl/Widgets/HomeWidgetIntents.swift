import AppIntents
import Foundation
import HomeCore

struct HomeWidgetEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Home control")
    static var defaultQuery = HomeWidgetEntityQuery()
    var id: String
    var name: String
    var room: String?
    var category: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\([category, room].compactMap { $0 }.joined(separator: " · "))")
    }
    init(_ value: FavoriteControl) { id = value.id; name = value.name; room = value.room; category = HomeWidgetSelection.typeName(for: value) }
    init(missingID: String) { id = missingID; name = L10n.text("Item indisponível"); room = nil; category = "" }
}

struct HomeWidgetEntityQuery: EntityStringQuery {
    private func options() throws -> [FavoriteControl] {
        guard let snapshot = try ControlSharedStore.configured()?.read() else { return [] }
        return HomeWidgetSelection.options(in: snapshot)
    }
    func entities(for identifiers: [String]) async throws -> [HomeWidgetEntity] {
        let values = (try? options()) ?? []
        return identifiers.map { id in
            values.first { $0.id == id }.map(HomeWidgetEntity.init) ?? HomeWidgetEntity(missingID: id)
        }
    }
    func suggestedEntities() async throws -> [HomeWidgetEntity] { try options().map(HomeWidgetEntity.init) }
    func entities(matching string: String) async throws -> [HomeWidgetEntity] {
        try options().filter { HomeWidgetSelection.matches($0, query: string) }.map(HomeWidgetEntity.init)
    }
}

struct SelectHomeWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Home controls"
    static var description = IntentDescription("Choose and order up to four controls for this widget.")
    @Parameter(title: "Items", default: [], size: .init(min: 0, max: 4)) var items: [HomeWidgetEntity]
    static var parameterSummary: some ParameterSummary {
        Summary { \.$items }
    }
}

struct SetHomeWidgetPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Set device power"
    static var isDiscoverable = false
    static var openAppWhenRun = false
    @Parameter(title: "Home control") var device: HomeWidgetEntity
    @Parameter(title: "On") var desired: Bool
    init() {}
    init(device: HomeWidgetEntity, desired: Bool) { self.device = device; self.desired = desired }
    func perform() async throws -> some IntentResult {
        try await ControlIntentBridge.perform(.homeWidget(device.id, desired))
        return .result()
    }
}

struct ActivateHomeWidgetSceneIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate scene"
    static var isDiscoverable = false
    static var openAppWhenRun = false
    @Parameter(title: "Home control") var device: HomeWidgetEntity
    init() {}
    init(device: HomeWidgetEntity) { self.device = device }
    func perform() async throws -> some IntentResult {
        try await ControlIntentBridge.perform(.homeWidget(device.id, nil))
        return .result()
    }
}

@available(macOSApplicationExtension, unavailable)
extension SetHomeWidgetPowerIntent: ForegroundContinuableIntent {}
@available(macOSApplicationExtension, unavailable)
extension ActivateHomeWidgetSceneIntent: ForegroundContinuableIntent {}
