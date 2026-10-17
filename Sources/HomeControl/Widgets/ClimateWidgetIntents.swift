import AppIntents
import Foundation
import HomeCore

struct ClimateDeviceEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Home control")
    static var defaultQuery = ClimateDeviceQuery()
    var id: String
    var name: String
    var room: String?
    var category: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\([category, room].compactMap { $0 }.joined(separator: " · "))")
    }
    init(_ device: FavoriteControl) { id = device.id; name = device.name; room = device.room; category = HomeWidgetSelection.typeName(for: device) }
    init(missingID: String) { id = missingID; name = L10n.text("Item indisponível"); room = nil; category = "" }
}

struct ClimateDeviceQuery: EntityStringQuery {
    private func devices() throws -> [FavoriteControl] {
        guard let snapshot = try ControlSharedStore.configured()?.read() else { return [] }
        return HomeWidgetSelection.options(in: snapshot)
    }
    func entities(for identifiers: [String]) async throws -> [ClimateDeviceEntity] {
        let values = (try? devices()) ?? []
        return identifiers.map { id in
            values.first { $0.id == id }.map(ClimateDeviceEntity.init) ?? ClimateDeviceEntity(missingID: id)
        }
    }
    func suggestedEntities() async throws -> [ClimateDeviceEntity] { try devices().map(ClimateDeviceEntity.init) }
    func defaultResult() async -> ClimateDeviceEntity? { nil }
    func entities(matching string: String) async throws -> [ClimateDeviceEntity] {
        try devices().filter { HomeWidgetSelection.matches($0, query: string) }.map(ClimateDeviceEntity.init)
    }
}

struct SelectClimateWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "One device"
    static var description = IntentDescription("Choose a light, switch, air conditioner, fan or scene.")
    @Parameter(title: "Device") var device: ClimateDeviceEntity?
    static var parameterSummary: some ParameterSummary { Summary { \.$device } }
}

struct AdjustClimateWidgetTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "Adjust temperature"
    static var isDiscoverable = false
    static var openAppWhenRun = false
    @Parameter(title: "Air conditioner") var device: ClimateDeviceEntity
    @Parameter(title: "Adjustment") var direction: Int
    init() {}
    init(device: ClimateDeviceEntity, direction: Int) { self.device = device; self.direction = direction }
    func perform() async throws -> some IntentResult {
        try await ControlIntentBridge.perform(.temperature(device.id, direction))
        return .result()
    }
}

struct SetClimateWidgetPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Set air conditioner power"
    static var isDiscoverable = false
    static var openAppWhenRun = false
    @Parameter(title: "Air conditioner") var device: ClimateDeviceEntity
    @Parameter(title: "On") var desired: Bool
    init() {}
    init(device: ClimateDeviceEntity, desired: Bool) { self.device = device; self.desired = desired }
    func perform() async throws -> some IntentResult {
        try await ControlIntentBridge.perform(.widgetPower(device.id, desired))
        return .result()
    }
}

@available(macOSApplicationExtension, unavailable)
extension AdjustClimateWidgetTemperatureIntent: ForegroundContinuableIntent {}

@available(macOSApplicationExtension, unavailable)
extension SetClimateWidgetPowerIntent: ForegroundContinuableIntent {}
