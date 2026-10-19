import SwiftUI
import HomeCore

enum Palette {
    static let background = Color(red: 0.047, green: 0.051, blue: 0.047)
    static let surface = Color.white.opacity(0.065)
    static let raised = Color.white.opacity(0.11)
    static let accent = Color(red: 0.70, green: 0.68, blue: 0.58)
    static let text = Color(red: 0.91, green: 0.91, blue: 0.87)
    static let secondary = Color(red: 0.78, green: 0.79, blue: 0.74)
    static let line = Color.white.opacity(0.12)
    static let good = Color(red: 0.65, green: 0.76, blue: 0.56)
    static let warning = Color(red: 0.94, green: 0.72, blue: 0.49)
}

struct NativeGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let effect = NSVisualEffectView()
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)
        container.addSubview(effect)
        let tint = NSView()
        tint.autoresizingMask = [.width, .height]
        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.62).cgColor
        container.addSubview(tint)
        return container
    }
    func updateNSView(_ view: NSView, context: Context) {}
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 11
    func body(content: Content) -> some View {
        content.overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75))
    }
}

struct TactileButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Palette.background : Palette.text)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(prominent ? Palette.accent : Palette.raised, in: RoundedRectangle(cornerRadius: 11))
            .modifier(GlassSurface())
            .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.4)
    }
}

struct IconButton: View {
    let icon: String
    let label: String
    var active = false
    var size: CGFloat = 36
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
                .foregroundStyle(active ? Palette.accent : Palette.secondary)
                .frame(width: size, height: size)
                .background(active ? Palette.raised : Color.clear, in: Circle())
        }
        .buttonStyle(.plain).accessibilityLabel(label).help(label)
    }
}

struct OptionTile: View {
    let icon: String
    let title: String
    let value: String
    let options: [String]
    let action: (String) -> Void
    @State private var open = false
    var body: some View {
        Button { open.toggle() } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: icon).font(.system(size: 20, weight: .light))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .medium))
                }.foregroundStyle(Palette.accent)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
                Text(displayName(value)).font(.system(size: 12, weight: .semibold))
                    .lineLimit(2, reservesSpace: true).fixedSize(horizontal: false, vertical: true)
            }
            .padding(11).frame(maxWidth: .infinity, alignment: .leading).frame(height: 94)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 11))
            .modifier(GlassSurface())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .bottom) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            open = false
                            action(option)
                        } label: {
                            HStack(spacing: 10) {
                                Text(displayName(option)).lineLimit(2)
                                Spacer(minLength: 10)
                                if option == value { Image(systemName: "checkmark").foregroundStyle(Palette.accent) }
                            }.font(.system(size: 12)).padding(10).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }.padding(5)
            }.frame(width: 180, height: min(300, CGFloat(options.count) * 40 + 10))
                .background(Palette.surface).foregroundStyle(Palette.text).preferredColorScheme(.dark)
        }
        .accessibilityLabel(title).accessibilityValue(displayName(value))
    }
}

func displayNumber(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "—" }
    return L10n.number(value)
}

func displayName(_ value: String) -> String {
    let names = ["cool": L10n.text("Resfriar"), "heat": L10n.text("Aquecer"), "off": L10n.text("Desligado"), "on": L10n.text("Ligado"),
                 "auto": L10n.text("Auto"), "heat_cool": L10n.text("Aquecer / resfriar"), "dry": L10n.text("Desumidificar"), "fan_only": L10n.text("Ventilar"),
                 "low": L10n.text("Baixa"), "medium": L10n.text("Média"), "high": L10n.text("Alta"), "none": L10n.text("Nenhum"), "eco": L10n.text("Eco"),
                 "sleep": L10n.text("Sono"), "comfort": L10n.text("Conforto"), "home": L10n.text("Em casa"), "away": L10n.text("Ausente"), "boost": L10n.text("Turbo"),
                 "vertical": L10n.text("Vertical"), "horizontal": L10n.text("Horizontal"), "both": L10n.text("Ambos"), "normal": L10n.text("Normal"),
                 "open": L10n.text("Aberta"), "closed": L10n.text("Fechada"), "opening": L10n.text("Abrindo"), "closing": L10n.text("Fechando"),
                 "unavailable": L10n.text("Indisponível"), "unknown": L10n.text("Sem leitura"), "cooling": L10n.text("Resfriando"),
                 "heating": L10n.text("Aquecendo"), "idle": L10n.text("Em espera"), "drying": L10n.text("Desumidificando"), "fan": L10n.text("Ventilando")]
    let aliases = ["quiet": L10n.text("Silencioso"), "silent": L10n.text("Silencioso"), "turbo": L10n.text("Turbo"),
                   "mid": L10n.text("Média"), "med": L10n.text("Média"), "min": L10n.text("Mínima"),
                   "minimum": L10n.text("Mínima"), "max": L10n.text("Máxima"), "maximum": L10n.text("Máxima")]
    let vacuumValues = [
        "vacuuming": L10n.text("Aspirar"),
        "mopping": L10n.text("Passar pano"),
        "vacuuming & mopping": L10n.text("Aspirar e passar pano"),
        "vacuuming before mopping": L10n.text("Aspirar antes do pano"),
        "once": L10n.text("Uma vez"),
        "twice": L10n.text("Duas vezes"),
        "three time": L10n.text("Três vezes"),
        "triple": L10n.text("Três vezes"),
        "level 1": L10n.text("Nível 1"),
        "level 2": L10n.text("Nível 2"),
        "level 3": L10n.text("Nível 3"),
        "standard": L10n.text("Padrão"),
        "strong": L10n.text("Forte"),
        "silent": L10n.text("Silencioso"),
        "docked": L10n.text("Na base"),
        "cleaning": L10n.text("Limpando"),
        "paused": L10n.text("Pausado"),
        "returning": L10n.text("Voltando à base"),
        "charging": L10n.text("Carregando"),
        "not charging": L10n.text("Sem carregar"),
        "not chargeable": L10n.text("Não pode carregar"),
        "by room": L10n.text("Por cômodo"),
        "by area": L10n.text("Por área"),
        "by time": L10n.text("Por tempo"),
        "deep": L10n.text("Intensa"),
        "daily": L10n.text("Diária"),
        "save water": L10n.text("Economizar água"),
        "not full": L10n.text("Não está cheio"),
        "full": L10n.text("Cheio"),
        "not empty": L10n.text("Com água"),
        "empty": L10n.text("Vazio"),
        "quick": L10n.text("Rápida"),
        "careful": L10n.text("Cuidadosa"),
        "every time": L10n.text("Sempre"),
        "7 sweeps": L10n.text("A cada 7 limpezas"),
        "self adaption": L10n.text("Adaptar automaticamente"),
        "avoid": L10n.text("Evitar"),
        "ignore": L10n.text("Ignorar"),
        "span": L10n.text("Atravessar"),
        "less collisions": L10n.text("Menos colisões"),
        "high coverage": L10n.text("Maior cobertura"),
        "ordinary temperature": L10n.text("Ambiente"),
        "warm": L10n.text("Morna"),
        "hot": L10n.text("Quente"),
        "smart": L10n.text("Inteligente")
    ]
    return names[value] ?? aliases[value] ?? vacuumValues[value.lowercased()] ?? value.replacingOccurrences(of: "_", with: " ").capitalized
}

struct ControlSlider: View {
    let label: String
    let value: Double?
    var bounds: ClosedRange<Double> = 0...100
    var step: Double = 1
    var unit = ""
    var showButtons = false
    var onPreview: ((Double?) -> Void)? = nil
    let onCommit: (Double) -> Void
    @Environment(\.isEnabled) private var enabled
    @State private var draft: Double?
    @FocusState private var focused: Bool
    private var current: Double { min(bounds.upperBound, max(bounds.lowerBound, draft ?? value ?? bounds.lowerBound)) }
    private var fraction: Double { (current - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound) }
    var body: some View {
        HStack(spacing: 12) {
            if showButtons { adjustButton("minus", delta: -step) }
            GeometryReader { geometry in
                let travel = max(1, geometry.size.width - 28)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14).fill(Palette.surface)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [Palette.accent.opacity(0.38), Palette.accent.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(28, 28 + travel * fraction))
                    RoundedRectangle(cornerRadius: 9).fill(Palette.text)
                        .frame(width: 22, height: 32).shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                        .offset(x: 3 + travel * fraction)
                }
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(focused ? Palette.accent : Palette.line, lineWidth: focused ? 2 : 1))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                    guard enabled, value != nil else { return }
                    focused = true
                    draft = snapped(bounds.lowerBound + (min(travel, max(0, event.location.x - 14)) / travel) * (bounds.upperBound - bounds.lowerBound))
                    onPreview?(draft)
                }.onEnded { _ in
                    guard enabled, let draft else { return }
                    onCommit(draft); self.draft = nil; onPreview?(nil)
                })
                .focusable(enabled && value != nil).focused($focused)
                .onMoveCommand { direction in
                    guard enabled, value != nil else { return }
                    if direction == .left || direction == .down { onCommit(snapped(current - step)) }
                    if direction == .right || direction == .up { onCommit(snapped(current + step)) }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label).accessibilityValue("\(displayNumber(draft ?? value)) \(unit)")
                .accessibilityAdjustableAction { direction in
                    guard enabled, value != nil else { return }
                    onCommit(snapped(current + (direction == .increment ? step : -step)))
                }
            }.frame(height: 40)
            if showButtons { adjustButton("plus", delta: step) }
        }
        .opacity(enabled && value != nil ? 1 : 0.4)
        .help(L10n.format("Arraste para ajustar %@. Use as setas do teclado ou os botões de menos e mais.", label.lowercased()))
        .onDisappear { draft = nil; onPreview?(nil) }
    }
    private func snapped(_ number: Double) -> Double {
        min(bounds.upperBound, max(bounds.lowerBound, bounds.lowerBound + ((number - bounds.lowerBound) / max(step, 0.01)).rounded() * max(step, 0.01)))
    }
    private func adjustButton(_ icon: String, delta: Double) -> some View {
        Button { onCommit(snapped(current + delta)) } label: {
            Image(systemName: icon).font(.system(size: 15, weight: .medium))
                .frame(width: 36, height: 36).background(Palette.surface, in: Circle())
        }.buttonStyle(.plain)
            .disabled(value == nil || (delta < 0 ? current <= bounds.lowerBound : current >= bounds.upperBound))
            .accessibilityLabel(L10n.format(delta < 0 ? "Diminuir %@" : "Aumentar %@", label.lowercased()))
    }
}
