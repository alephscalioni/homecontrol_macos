import AppKit
import HomeCore
import SwiftUI

/// Shared by the real WidgetKit entry and its interactive demonstration.
struct ClimateWidgetCard<Power: View, Adjustments: View>: View {
    let favorite: FavoriteControl
    let connected: Bool
    var demo = false
    var showsEditHint = false
    let power: Power
    let adjustments: Adjustments

    init(favorite: FavoriteControl, connected: Bool, demo: Bool = false, showsEditHint: Bool = false,
         @ViewBuilder power: () -> Power, @ViewBuilder adjustments: () -> Adjustments) {
        self.favorite = favorite; self.connected = connected; self.demo = demo
        self.showsEditHint = showsEditHint
        self.power = power(); self.adjustments = adjustments()
    }

    private var climate: ClimateWidgetState? { favorite.climate }
    private var usable: Bool { connected && favorite.available }
    private var status: String {
        guard usable else { return L10n.text("Sem conexão") }
        if demo { return L10n.text("Demonstração") }
        let names = ["cooling": "Resfriando", "heating": "Aquecendo", "idle": "Em espera", "off": "Desligado",
                     "cool": "Resfriar", "heat": "Aquecer", "dry": "Desumidificar", "fan_only": "Ventilar", "auto": "Auto"]
        let value = favorite.isOn ? (climate?.action ?? climate?.mode ?? "") : "off"
        return L10n.text(names[value] ?? value)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(favorite.room ?? favorite.name)
                        .font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                    if showsEditHint { Text(L10n.text("Trocar item: botão direito → Editar")).font(.system(size: 9)).foregroundStyle(WidgetInk.secondary).lineLimit(1) }
                }
                Spacer(minLength: 4)
                Text(status).font(.system(size: 10, weight: .medium)).foregroundStyle(WidgetInk.secondary).lineLimit(1)
                power
            }
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(climate?.target.map { L10n.number($0) } ?? "—")
                            .font(.system(size: 44, weight: .medium, design: .rounded)).tracking(-1.5).monospacedDigit()
                        Text(climate?.unit ?? "°C").font(.system(size: 17, weight: .regular)).foregroundStyle(WidgetInk.secondary)
                    }.accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.text("Temperatura desejada"))
                        .accessibilityValue("\(climate?.target.map { L10n.number($0) } ?? "—") \(climate?.unit ?? "°C")")
                    Label {
                        Text(L10n.format("Ambiente %@%@", climate?.current.map { L10n.number($0) } ?? "—", climate?.unit ?? "°C"))
                    } icon: { Image(systemName: "thermometer.medium") }
                        .font(.system(size: 10)).foregroundStyle(WidgetInk.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 6) {
                    WidgetAirConditioner(isOn: favorite.isOn && usable).frame(width: 116, height: 40)
                    adjustments
                }
            }
        }.padding(16).foregroundStyle(WidgetInk.text)
    }
}

enum WidgetInk {
    static let text = Color(red: 0.91, green: 0.91, blue: 0.87)
    static let secondary = Color(red: 0.78, green: 0.79, blue: 0.74)
    static let accent = Color(red: 0.70, green: 0.68, blue: 0.58)
    static let background = Color(red: 0.047, green: 0.051, blue: 0.047)
}

struct WidgetTemperatureButtonStyle: ButtonStyle {
    var width: CGFloat = 48
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .medium))
            .frame(width: width, height: 30)
            .foregroundStyle(WidgetInk.text.opacity(enabled ? 1 : 0.35))
            .background(.white.opacity(configuration.isPressed ? 0.20 : 0.10), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct WidgetPowerButtonStyle: ButtonStyle {
    let isOn: Bool
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .regular))
            .frame(width: 28, height: 28)
            .foregroundStyle((isOn ? WidgetInk.accent : WidgetInk.secondary).opacity(enabled ? 1 : 0.35))
            .background((isOn ? WidgetInk.accent : .white).opacity(configuration.isPressed ? 0.25 : 0.11), in: Circle())
            .contentShape(Circle())
    }
}

private struct WidgetAirConditioner: View {
    let isOn: Bool
    private static let image: NSImage? = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        let url = bundle.url(forResource: "air-conditioner", withExtension: "png")
            ?? bundle.url(forResource: "air-conditioner", withExtension: "png", subdirectory: "Resources")
        return url.flatMap { NSImage(contentsOf: $0) }
    }()
    var body: some View {
        ZStack(alignment: .top) {
            if isOn {
                Canvas { context, size in
                    for index in 0..<9 {
                        let x = size.width / 2 + Double(index - 4) * 8
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 26))
                        path.addCurve(to: CGPoint(x: x + Double(index - 4), y: 40),
                                      control1: CGPoint(x: x - 1, y: 31), control2: CGPoint(x: x + 1, y: 36))
                        context.stroke(path, with: .linearGradient(Gradient(colors: [.white.opacity(0.23), .clear]),
                            startPoint: CGPoint(x: 0, y: 26), endPoint: CGPoint(x: 0, y: 40)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                    }
                }.blur(radius: 0.8)
            }
            if let image = Self.image {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 116, height: 38).offset(y: -5)
                    .opacity(isOn ? 1 : 0.55)
            } else { Image(systemName: "air.conditioner.horizontal.fill").font(.system(size: 35)).opacity(isOn ? 1 : 0.55) }
        }.accessibilityHidden(true)
    }
}
