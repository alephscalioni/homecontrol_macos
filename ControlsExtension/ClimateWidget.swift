import AppIntents
import HomeCore
import SwiftUI
import WidgetKit

struct HomeClimateWidget: Widget {
    static let kind = "br.com.homecontrol.climateWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: SelectClimateWidgetIntent.self, provider: ClimateWidgetProvider()) { entry in
            ClimateWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { WidgetInk.background }
        }
        .configurationDisplayName("One device")
        .description("Choose a light, switch, air conditioner, fan or scene.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct ClimateWidgetEntry: TimelineEntry {
    let date: Date
    let favorite: FavoriteControl?
    let connected: Bool
    var demo = false

    static var preview: ClimateWidgetEntry {
        let entity = HAEntity("climate.preview", state: "cool", attributes: [
            "friendly_name": .string(L10n.text("Ar-condicionado do quarto")), "temperature": .number(22),
            "current_temperature": .number(24), "temperature_unit": .string("°C"),
            "min_temp": .number(16), "max_temp": .number(32), "target_temp_step": .number(1),
            "supported_features": .number(385), "hvac_action": .string("cooling")
        ])
        return ClimateWidgetEntry(date: Date(), favorite: FavoriteControl(entity: entity, serverID: "preview", room: L10n.text("Quarto")), connected: true, demo: true)
    }
}

struct ClimateWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClimateWidgetEntry { .preview }
    func snapshot(for configuration: SelectClimateWidgetIntent, in context: Context) async -> ClimateWidgetEntry {
        context.isPreview ? .preview : current(configuration)
    }
    func timeline(for configuration: SelectClimateWidgetIntent, in context: Context) async -> Timeline<ClimateWidgetEntry> {
        Timeline(entries: [current(configuration)], policy: .after(Date().addingTimeInterval(300)))
    }
    private func current(_ configuration: SelectClimateWidgetIntent) -> ClimateWidgetEntry {
        guard let cache = ControlSharedStore.configured(), let snapshot = try? cache.read() else {
            return ClimateWidgetEntry(date: Date(), favorite: nil, connected: false)
        }
        let values = HomeWidgetSelection.options(in: snapshot)
        let favorite: FavoriteControl?
        if let selected = configuration.device { favorite = values.first { $0.id == selected.id } }
        else { favorite = nil }
        return ClimateWidgetEntry(date: Date(), favorite: favorite, connected: ControlSharedStore.isFresh(snapshot),
                                  demo: snapshot.serverID == FavoriteControl.serverID(for: "homecontrol-demo"))
    }
}

private struct ClimateWidgetEntryView: View {
    let entry: ClimateWidgetEntry
    var body: some View {
        if let favorite = entry.favorite {
            SingleDeviceWidgetCard(control: favorite, connected: entry.connected, demo: entry.demo) {
                WidgetPowerAction(control: favorite, connected: entry.connected)
            } adjustments: {
                WidgetTemperatureActions(control: favorite, connected: entry.connected)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 28, weight: .light)).foregroundStyle(WidgetInk.accent)
                Text(L10n.text("Escolha um aparelho ou cena")).font(.system(size: 13, weight: .semibold))
                Text(L10n.text("Clique com o botão direito neste widget e escolha Editar. Depois selecione um aparelho ou cena."))
                    .font(.system(size: 11)).foregroundStyle(WidgetInk.secondary).multilineTextAlignment(.center)
            }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity).foregroundStyle(WidgetInk.text)
        }
    }
}
