import AppIntents
import HomeCore
import SwiftUI
import WidgetKit

struct HomeControlsWidget: Widget {
    static let kind = "br.com.homecontrol.homeWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectHomeWidgetIntent.self, provider: HomeWidgetProvider()) { entry in
            HomeWidgetEntryView(entry: entry).containerBackground(for: .widget) { WidgetInk.background }
        }
        .configurationDisplayName("Up to 4 controls")
        .description("Choose up to four lights, switches, air conditioners or scenes.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct HomeWidgetEntry: TimelineEntry {
    let date: Date
    let items: [HomeWidgetItem]
    let connected: Bool
    var demo = false
    static var preview: HomeWidgetEntry {
        let entities = [
            HAEntity("climate.preview", state: "cool", attributes: ["friendly_name": .string(L10n.text("Ar-condicionado do quarto")), "temperature": .number(22), "temperature_unit": .string("°C"), "supported_features": .number(385)]),
            HAEntity("light.preview", state: "on", attributes: ["friendly_name": .string(L10n.text("Luz da sala"))]),
            HAEntity("switch.preview", state: "off", attributes: ["friendly_name": .string(L10n.text("Cafeteira"))]),
            HAEntity("scene.preview", state: "2026-10-15T00:00:00Z", attributes: ["friendly_name": .string(L10n.text("Boa noite"))])
        ]
        let rooms = [L10n.text("Quarto"), L10n.text("Sala"), L10n.text("Cozinha"), L10n.text("Cena")]
        return HomeWidgetEntry(date: Date(), items: zip(entities, rooms).map {
            HomeWidgetItem(FavoriteControl(entity: $0.0, serverID: "preview", room: $0.1))
        }, connected: true, demo: true)
    }
}

struct HomeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomeWidgetEntry { .preview }
    func snapshot(for configuration: SelectHomeWidgetIntent, in context: Context) async -> HomeWidgetEntry {
        context.isPreview ? .preview : current(configuration)
    }
    func timeline(for configuration: SelectHomeWidgetIntent, in context: Context) async -> Timeline<HomeWidgetEntry> {
        Timeline(entries: [current(configuration)], policy: .after(Date().addingTimeInterval(300)))
    }
    private func current(_ configuration: SelectHomeWidgetIntent) -> HomeWidgetEntry {
        let snapshot = try? ControlSharedStore.configured()?.read()
        let ids = HomeWidgetSelection.identifiers(configuration.items.map(\.id))
        let values = snapshot.map { HomeWidgetSelection.resolve(ids, in: $0) } ?? ids.map { _ in nil }
        let items = zip(ids, values).map { id, value in
            HomeWidgetItem(id: id, name: configuration.items.first { $0.id == id }?.name ?? "", control: value)
        }
        return HomeWidgetEntry(date: Date(), items: items, connected: snapshot.map { ControlSharedStore.isFresh($0) } == true,
                               demo: snapshot?.serverID == FavoriteControl.serverID(for: "homecontrol-demo"))
    }
}

private struct HomeWidgetEntryView: View {
    let entry: HomeWidgetEntry
    var body: some View {
        HomeWidgetBoard(items: entry.items, connected: entry.connected, demo: entry.demo, showsEditHint: true) { item in
            HomeWidgetTile(item: item, connected: entry.connected) {
                if let control = item.control { WidgetPowerAction(control: control, connected: entry.connected) }
            } adjustments: {
                if let control = item.control { WidgetTemperatureActions(control: control, connected: entry.connected, compact: true) }
            }
        }
    }
}
