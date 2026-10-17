import AppIntents
import HomeCore
import SwiftUI

struct WidgetPowerAction: View {
    let control: FavoriteControl
    let connected: Bool
    private var ready: Bool { connected && control.available }
    var body: some View {
        if let climate = control.climate {
            Button(intent: SetClimateWidgetPowerIntent(device: ClimateDeviceEntity(control), desired: !control.isOn)) { Image(systemName: "power") }
                .buttonStyle(WidgetPowerButtonStyle(isOn: control.isOn))
                .disabled(!ready || !(control.isOn ? climate.canPowerOff : climate.canPowerOn))
                .accessibilityLabel(L10n.format(control.isOn ? "Desligar %@" : "Ligar %@", control.name))
        } else if control.kind == .scene {
            Button(intent: ActivateHomeWidgetSceneIntent(device: HomeWidgetEntity(control))) {
                Label(L10n.text("Ativar"), systemImage: "play.fill")
            }.buttonStyle(HomeWidgetActionStyle(active: false)).disabled(!ready)
                .accessibilityLabel(L10n.format("Ativar cena %@", control.name))
        } else {
            Button(intent: SetHomeWidgetPowerIntent(device: HomeWidgetEntity(control), desired: !control.isOn)) {
                Label(L10n.text(control.isOn ? "Ligado" : "Desligado"), systemImage: "power")
            }.buttonStyle(HomeWidgetActionStyle(active: control.isOn)).disabled(!ready || control.kind != .toggle)
                .accessibilityLabel(L10n.format(control.isOn ? "Desligar %@" : "Ligar %@", control.name))
        }
    }
}

struct WidgetTemperatureActions: View {
    let control: FavoriteControl
    let connected: Bool
    var compact = false
    var body: some View {
        if let climate = control.climate, climate.isSingleTarget {
            HStack(spacing: compact ? 4 : 8) {
                Button(intent: AdjustClimateWidgetTemperatureIntent(device: ClimateDeviceEntity(control), direction: -1)) { Image(systemName: "minus") }
                    .buttonStyle(WidgetTemperatureButtonStyle(width: compact ? 28 : 48))
                    .disabled(!connected || !control.available || !climate.canDecrease)
                    .accessibilityLabel(L10n.format("Diminuir temperatura de %@", control.name))
                Button(intent: AdjustClimateWidgetTemperatureIntent(device: ClimateDeviceEntity(control), direction: 1)) { Image(systemName: "plus") }
                    .buttonStyle(WidgetTemperatureButtonStyle(width: compact ? 28 : 48))
                    .disabled(!connected || !control.available || !climate.canIncrease)
                    .accessibilityLabel(L10n.format("Aumentar temperatura de %@", control.name))
            }
        }
    }
}
