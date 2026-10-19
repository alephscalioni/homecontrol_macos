import SwiftUI
import HomeCore

struct DeviceDetail: View {
    let entity: HAEntity
    var body: some View {
        switch entity.domain {
        case "camera": CameraDetailView(entity: entity)
        case "vacuum": VacuumDetailView(entity: entity)
        case "climate": ClimateView(entity: entity)
        case "light": LightView(entity: entity)
        case "fan": FanView(entity: entity)
        case "cover": CoverView(entity: entity)
        default: EmptyView()
        }
    }
}

struct ClimateView: View {
    @EnvironmentObject private var store: HomeStore
    let entity: HAEntity
    @State private var temperaturePreview: Double?
    var body: some View {
        VStack(spacing: 12) {
            AirConditionerView(airflow: ClimateAirflow(entity: entity), animated: store.isPanelVisible && store.canControl)
                .frame(height: 118)
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(entity.usesTemperatureRange ? "\(displayNumber(entity.number("target_temp_low")))–\(displayNumber(entity.number("target_temp_high")))" : displayNumber(temperaturePreview ?? entity.number("temperature")))
                        .font(.system(size: entity.usesTemperatureRange ? 43 : 58, weight: .medium, design: .rounded)).tracking(-2).monospacedDigit()
                    Text(entity.temperatureUnit).font(.system(size: 24, weight: .medium)).foregroundStyle(Palette.secondary)
                }.accessibilityElement(children: .combine).accessibilityLabel(L10n.text("Temperatura desejada"))
                    .accessibilityValue(entity.usesTemperatureRange ? L10n.format("%@ a %@ %@", displayNumber(entity.number("target_temp_low")), displayNumber(entity.number("target_temp_high")), entity.temperatureUnit) : "\(displayNumber(entity.number("temperature"))) \(entity.temperatureUnit)")
                Spacer(minLength: 4)
                if entity.supports(16), entity.options("preset_modes").contains("eco") {
                    if entity.options("preset_modes").contains("none") {
                        Button {
                            store.execute(ServiceCall(entity, "set_preset_mode", data: ["preset_mode": .string(entity.text("preset_mode") == "eco" ? "none" : "eco")]))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "leaf.fill").foregroundStyle(Palette.accent)
                                Text(L10n.text("Eco")).font(.system(size: 12, weight: .semibold))
                                ZStack(alignment: entity.text("preset_mode") == "eco" ? .trailing : .leading) {
                                    Capsule().fill(entity.text("preset_mode") == "eco" ? Palette.accent : Palette.raised)
                                    Circle().fill(Palette.text).padding(2)
                                }.frame(width: 35, height: 21)
                            }.padding(10).background(Palette.surface, in: RoundedRectangle(cornerRadius: 11)).modifier(GlassSurface())
                        }.buttonStyle(.plain).accessibilityLabel(L10n.text("Modo Eco")).accessibilityValue(entity.text("preset_mode") == "eco" ? L10n.text("Ativado") : L10n.text("Desativado"))
                    }
                }
            }.frame(height: 59)
            if entity.usesTemperatureRange {
                rangeControl(title: L10n.text("Mínima"), key: "target_temp_low", high: false)
                rangeControl(title: L10n.text("Máxima"), key: "target_temp_high", high: true)
            } else if entity.supports(1), entity.number("temperature") != nil {
                VStack(spacing: 8) {
                    ControlSlider(label: L10n.text("Temperatura"), value: entity.number("temperature"), bounds: entity.temperatureBounds, step: entity.temperatureStep, unit: entity.temperatureUnit, showButtons: true, onPreview: { temperaturePreview = $0 }) {
                        store.execute(ServiceCall.temperature(entity, value: $0))
                    }
                    HStack {
                        Text("\(displayNumber(entity.temperatureBounds.lowerBound))°")
                        Spacer()
                        Text(temperaturePreview == nil ? L10n.text("Arraste ou use − / +") : L10n.text("Solte para ajustar")).font(.system(size: 10))
                        Spacer()
                        Text("\(displayNumber(entity.temperatureBounds.upperBound))°")
                    }.font(.system(size: 10)).foregroundStyle(Palette.secondary).padding(.horizontal, 49)
                }
            } else if entity.supports(1) {
                Text(entity.isOn ? L10n.text("O Home Assistant não informou a temperatura de ajuste.") : L10n.text("Ligue ou selecione um modo para ajustar a temperatura."))
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                if !entity.options("hvac_modes").isEmpty {
                    OptionTile(icon: "snowflake", title: L10n.text("Modo"), value: entity.state, options: entity.options("hvac_modes")) { store.execute(ServiceCall(entity, "set_hvac_mode", data: ["hvac_mode": .string($0)])) }
                }
                if entity.supports(8), !entity.options("fan_modes").isEmpty {
                    OptionTile(icon: "fan", title: L10n.text("Velocidade"), value: entity.text("fan_mode") ?? "—", options: entity.options("fan_modes")) { store.execute(ServiceCall(entity, "set_fan_mode", data: ["fan_mode": .string($0)])) }
                }
                if entity.supports(16), !entity.options("preset_modes").isEmpty {
                    OptionTile(icon: "moon", title: L10n.text("Perfil"), value: entity.text("preset_mode") ?? "—", options: entity.options("preset_modes")) { store.execute(ServiceCall(entity, "set_preset_mode", data: ["preset_mode": .string($0)])) }
                }
                if entity.supports(32), !entity.options("swing_modes").isEmpty {
                    OptionTile(icon: "wind", title: L10n.text("Direção"), value: entity.text("swing_mode") ?? "—", options: entity.options("swing_modes")) { store.execute(ServiceCall(entity, "set_swing_mode", data: ["swing_mode": .string($0)])) }
                }
                if entity.supports(512), !entity.options("swing_horizontal_modes").isEmpty {
                    OptionTile(icon: "arrow.left.and.right", title: L10n.text("Horizontal"), value: entity.text("swing_horizontal_mode") ?? "—", options: entity.options("swing_horizontal_modes")) { store.execute(ServiceCall(entity, "set_swing_horizontal_mode", data: ["swing_horizontal_mode": .string($0)])) }
                }
            }
            if !entity.isOn { Text(L10n.text("Ar-condicionado desligado")).font(.system(size: 11)).foregroundStyle(Palette.secondary) }
        }.onChange(of: entity.id) { _, _ in temperaturePreview = nil }
    }
    private func rangeControl(title: String, key: String, high: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(title) · \(displayNumber(entity.number(key)))\(entity.temperatureUnit)").font(.system(size: 11)).foregroundStyle(Palette.secondary)
            ControlSlider(label: L10n.format("Temperatura %@", title.lowercased()), value: entity.number(key), bounds: entity.temperatureBounds, step: entity.temperatureStep, unit: entity.temperatureUnit) {
                store.execute(ServiceCall.temperature(entity, value: $0, high: high))
            }
        }
    }
}

struct LightView: View {
    @EnvironmentObject private var store: HomeStore
    let entity: HAEntity
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: entity.isOn ? "lightbulb.fill" : "lightbulb")
                .font(.system(size: 86, weight: .ultraLight)).foregroundStyle(entity.isOn ? Palette.accent : Palette.secondary).frame(height: 130).accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline) {
                Text(entity.isOn ? L10n.text("Ligada") : L10n.text("Desligada")).font(.system(size: 30, weight: .medium, design: .rounded))
                Spacer()
                if entity.supportsBrightness { Text("\(displayNumber(entity.number("brightness").map { $0 / 2.55 }))%").font(.system(size: 23, weight: .light)).foregroundStyle(Palette.secondary) }
            }
            if entity.supportsBrightness {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("Brilho")).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    ControlSlider(label: L10n.text("Brilho"), value: entity.isOn ? entity.number("brightness").map { ($0 / 2.55).rounded() } : 0, unit: "%", showButtons: true) { value in
                        store.execute(ServiceCall(entity, value == 0 ? "turn_off" : "turn_on", data: value == 0 ? [:] : ["brightness_pct": .number(value)]))
                    }
                }
            }
            if entity.options("supported_color_modes").contains("color_temp"), let min = entity.number("min_color_temp_kelvin"), let max = entity.number("max_color_temp_kelvin"), min < max {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text(L10n.text("Temperatura da luz")); Spacer(); Text("\(displayNumber(entity.number("color_temp_kelvin"))) K") }.font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    ControlSlider(label: L10n.text("Temperatura da luz"), value: entity.number("color_temp_kelvin"), bounds: min...max, step: 50, unit: "K") {
                        store.execute(ServiceCall(entity, "turn_on", data: ["color_temp_kelvin": .number($0.rounded())]))
                    }
                    HStack { Text(L10n.text("Quente")); Spacer(); Text(L10n.text("Fria")) }.font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }
        }
    }
}

struct FanView: View {
    @EnvironmentObject private var store: HomeStore
    let entity: HAEntity
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "fan").font(.system(size: 100, weight: .ultraLight)).foregroundStyle(entity.isOn ? Palette.accent : Palette.secondary).frame(height: 140).accessibilityHidden(true)
            HStack { Text(entity.isOn ? L10n.text("Ligado") : L10n.text("Desligado")).font(.system(size: 30, weight: .medium, design: .rounded)); Spacer() }
            if entity.supports(1) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack { Text(L10n.text("Velocidade")); Spacer(); Text("\(displayNumber(entity.number("percentage")))%") }.font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    ControlSlider(label: L10n.text("Velocidade do ventilador"), value: entity.number("percentage"), step: entity.number("percentage_step") ?? 1, unit: "%", showButtons: true) {
                        store.execute(ServiceCall(entity, "set_percentage", data: ["percentage": .number($0.rounded())]))
                    }
                }
            }
            HStack(spacing: 10) {
                if entity.supports(8), !entity.options("preset_modes").isEmpty {
                    OptionTile(icon: "moon", title: L10n.text("Perfil"), value: entity.text("preset_mode") ?? "—", options: entity.options("preset_modes")) { store.execute(ServiceCall(entity, "set_preset_mode", data: ["preset_mode": .string($0)])) }
                }
                if entity.supports(2) {
                    Toggle(L10n.text("Oscilar"), isOn: Binding(get: { entity.attributes["oscillating"]?.bool ?? false }, set: { store.execute(ServiceCall(entity, "oscillate", data: ["oscillating": .bool($0)])) }))
                        .toggleStyle(.switch).tint(Palette.accent).padding(14).frame(maxWidth: .infinity).frame(height: 82).background(Palette.surface, in: RoundedRectangle(cornerRadius: 11))
                }
            }
        }
    }
}

struct CoverView: View {
    @EnvironmentObject private var store: HomeStore
    let entity: HAEntity
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: entity.state == "closed" ? "blinds.horizontal.closed" : "blinds.horizontal.open")
                .font(.system(size: 102, weight: .ultraLight)).foregroundStyle(Palette.accent).frame(height: 160).accessibilityHidden(true)
            HStack { Text(displayName(entity.state)).font(.system(size: 32, weight: .medium, design: .rounded)); Spacer(); Text("\(displayNumber(entity.number("current_position")))%").font(.system(size: 24, weight: .light)).foregroundStyle(Palette.secondary) }
            if entity.supports(4) {
                ControlSlider(label: L10n.text("Abertura da cortina"), value: entity.number("current_position"), unit: "%") { store.execute(ServiceCall(entity, "set_cover_position", data: ["position": .number($0.rounded())])) }
                HStack { Text(L10n.text("Fechada")); Spacer(); Text(L10n.text("Aberta")) }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            HStack(spacing: 8) {
                if entity.supports(1) { Button { store.execute(ServiceCall(entity, "open_cover")) } label: { Label(L10n.text("Abrir"), systemImage: "chevron.up").frame(maxWidth: .infinity) }.buttonStyle(TactileButtonStyle()) }
                if entity.supports(8) { Button { store.execute(ServiceCall(entity, "stop_cover")) } label: { Label(L10n.text("Parar"), systemImage: "stop.fill").frame(maxWidth: .infinity) }.buttonStyle(TactileButtonStyle()) }
                if entity.supports(2) { Button { store.execute(ServiceCall(entity, "close_cover")) } label: { Label(L10n.text("Fechar"), systemImage: "chevron.down").frame(maxWidth: .infinity) }.buttonStyle(TactileButtonStyle()) }
            }.font(.system(size: 12))
        }
    }
}
