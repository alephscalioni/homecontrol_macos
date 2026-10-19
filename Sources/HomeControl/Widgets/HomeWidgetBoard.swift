import HomeCore
import SwiftUI
import WidgetKit

struct HomeWidgetItem: Identifiable {
    let id: String
    let name: String
    let control: FavoriteControl?
    init(_ control: FavoriteControl) { id = control.id; name = control.name; self.control = control }
    init(id: String, name: String, control: FavoriteControl?) {
        self.id = id; self.name = name; self.control = control
    }
}

/// Shared by WidgetKit and the interactive demo; each tile retains its selected identity.
struct HomeWidgetBoard<Content: View>: View {
    let items: [HomeWidgetItem]
    let connected: Bool
    var demo = false
    var showsEditHint = false
    @ViewBuilder let content: (HomeWidgetItem) -> Content

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(L10n.text("Minha casa")).font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(L10n.text(demo ? "Demonstração" : connected ? "Controles" : "Sem conexão"))
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(WidgetInk.secondary)
            }.frame(height: 20)
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 27, weight: .light)).foregroundStyle(WidgetInk.accent)
                    Text(L10n.text("Escolha seus controles")).font(.system(size: 14, weight: .semibold))
                    Text(L10n.text("Edite o widget para escolher até 4 itens, na ordem que preferir."))
                        .font(.system(size: 12)).foregroundStyle(WidgetInk.secondary).multilineTextAlignment(.center)
                }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let columns = items.count == 1 ? 1 : 2
                let rows = (items.count + columns - 1) / columns
                VStack(spacing: 10) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(0..<columns, id: \.self) { column in
                                let index = row * columns + column
                                if index < items.count {
                                    content(items[index]).frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else { Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity) }
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            if showsEditHint { WidgetEditHint().frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(14).foregroundStyle(WidgetInk.text)
    }
}

struct HomeWidgetTile<Power: View, Adjustments: View>: View {
    let item: HomeWidgetItem
    let connected: Bool
    var camera: CameraSnapshot?
    var demo = false
    @ViewBuilder let power: () -> Power
    @ViewBuilder let adjustments: () -> Adjustments

    var body: some View {
        if let control = item.control, control.isCamera {
            CameraWidgetCard(control: control, connected: connected, snapshot: camera, compact: true, demo: demo, actions: power)
        } else {
        VStack(alignment: .leading, spacing: 4) {
            if let control = item.control {
                HStack(spacing: 6) {
                    Image(systemName: control.symbol).font(.system(size: 16)).foregroundStyle(WidgetInk.accent)
                    Text(!connected ? L10n.text("Sem conexão") : !control.available ? L10n.text("Indisponível") : control.room ?? L10n.text(control.kind == .scene ? "Cena" : "Aparelho"))
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(WidgetInk.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    if control.climate?.isSingleTarget == true { power() }
                }.frame(height: 24)
                Text(control.name).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                if let climate = control.climate, climate.isSingleTarget {
                    HStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(climate.target.map { L10n.number($0) } ?? "—")
                                .font(.system(size: 28, weight: .medium, design: .rounded)).monospacedDigit()
                            Text(climate.unit).font(.system(size: 11)).foregroundStyle(WidgetInk.secondary)
                        }.lineLimit(1).minimumScaleFactor(0.75)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(L10n.format("Temperatura de %@", control.name))
                            .accessibilityValue("\(climate.target.map { L10n.number($0) } ?? "—") \(climate.unit)")
                        Spacer(minLength: 0)
                        adjustments()
                    }
                } else { power().frame(maxWidth: .infinity, alignment: .leading) }
            } else {
                Image(systemName: "questionmark.circle").foregroundStyle(WidgetInk.secondary)
                Text(item.name).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                Spacer(minLength: 0)
                Text(L10n.text("Edite o widget para escolher novamente."))
                    .font(.system(size: 11)).foregroundStyle(WidgetInk.secondary)
            }
        }.padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(item.control?.isOn == true && connected ? 0.11 : 0.055), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct HomeWidgetActionStyle: ButtonStyle {
    let active: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).lineLimit(1)
            .padding(.horizontal, 10).frame(height: 30)
            .foregroundStyle((active && renderingMode == .fullColor ? WidgetInk.background : WidgetInk.text).opacity(enabled ? 1 : 0.35))
            .background((active && renderingMode == .fullColor ? WidgetInk.accent : .white.opacity(active ? 0.24 : 0.12)).opacity(configuration.isPressed ? 0.65 : 1), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}
