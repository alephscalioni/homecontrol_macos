import HomeCore
import SwiftUI

struct WidgetEditHint: View {
    var multiple = true
    var body: some View {
        Label(L10n.text(multiple ? "Trocar itens: botão direito no widget → Editar" : "Trocar item: botão direito no widget → Editar"), systemImage: "cursorarrow")
            .font(.system(size: 10)).foregroundStyle(WidgetInk.secondary).lineLimit(2)
    }
}

struct SingleDeviceWidgetCard<Power: View, Adjustments: View>: View {
    let control: FavoriteControl
    let connected: Bool
    var demo = false
    var showsEditHint = true
    @ViewBuilder let power: () -> Power
    @ViewBuilder let adjustments: () -> Adjustments
    var body: some View {
        if control.climate?.isSingleTarget == true {
            ClimateWidgetCard(favorite: control, connected: connected, demo: demo, showsEditHint: showsEditHint,
                              power: power, adjustments: adjustments)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(control.name).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                        Text([HomeWidgetSelection.typeName(for: control), control.room].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 11)).foregroundStyle(WidgetInk.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: control.symbol).font(.system(size: 25, weight: .regular)).foregroundStyle(WidgetInk.accent)
                }
                Spacer(minLength: 0)
                HStack {
                    power()
                    Spacer()
                    if demo || !connected || !control.available {
                        Text(L10n.text(demo ? "Demonstração" : !connected ? "Sem conexão" : "Indisponível"))
                            .font(.system(size: 10)).foregroundStyle(WidgetInk.secondary)
                    }
                }
                if showsEditHint { WidgetEditHint(multiple: false) }
            }.padding(16).foregroundStyle(WidgetInk.text)
        }
    }
}
