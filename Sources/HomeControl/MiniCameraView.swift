import AppKit
import HomeCore
import SwiftUI

/// A live app window with a widget-like shape. WidgetKit remains snapshot-only.
final class MiniCameraWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

struct MiniCameraView: View {
    @EnvironmentObject private var store: HomeStore
    @Environment(\.controlActiveState) private var activeState
    @ObservedObject var session: CameraLiveSession
    let name: String
    @State private var staysOnTop: Bool
    let changeLevel: (Bool) -> Void
    let resize: () -> Void
    let expand: () -> Void
    let close: () -> Void
    @State private var hovering = false
    init(session: CameraLiveSession, name: String, staysOnTop: Bool, changeLevel: @escaping (Bool) -> Void, resize: @escaping () -> Void, expand: @escaping () -> Void, close: @escaping () -> Void) {
        self.session = session; self.name = name
        _staysOnTop = State(initialValue: staysOnTop)
        self.changeLevel = changeLevel; self.resize = resize; self.expand = expand; self.close = close
    }
    private var showsControls: Bool { hovering || activeState == .key || !session.running || session.error != nil }

    var body: some View {
        ZStack {
            Color.black
            if let image = session.image {
                Image(nsImage: image).resizable().scaledToFit()
                    .accessibilityLabel(L10n.format("Vídeo de %@", name))
            } else if session.running {
                ProgressView().controlSize(.small).tint(Palette.accent)
            } else {
                Image(systemName: "video.slash").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.secondary)
            }
            CameraWindowSurface(showsControls: showsControls).accessibilityHidden(true)
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let fresh = session.running && session.lastFrame.map { context.date.timeIntervalSince($0) < 5 } == true
                        Circle().fill(fresh ? Palette.good : Palette.secondary).frame(width: 5, height: 5)
                            .accessibilityLabel(L10n.text(store.isDemo ? "Demonstração" : fresh ? "Ao vivo" : session.running ? "Conectando…" : "Pausado"))
                    }
                    Text(name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 0)
                    if store.isDemo { Text(L10n.text("Demonstração")).font(.system(size: 9)) }
                }.foregroundStyle(Palette.text).padding(.horizontal, 12).padding(.vertical, 10)
                    .background(LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
                Spacer(minLength: 0)
                if let error = session.error {
                    Text(error).font(.system(size: 11)).foregroundStyle(Palette.text).multilineTextAlignment(.center)
                        .padding(10).frame(maxWidth: .infinity).background(.black.opacity(0.7))
                }
                if showsControls {
                    HStack(spacing: 6) {
                        miniButton(session.running ? "pause.fill" : "play.fill", label: L10n.text(session.running ? "Pausar" : "Conectar novamente")) {
                            session.running ? session.stop(clear: false) : session.start()
                        }
                        miniButton(staysOnTop ? "pin.fill" : "pin.slash", label: L10n.text(staysOnTop ? "Desativar sempre por cima" : "Sempre por cima")) { staysOnTop.toggle(); changeLevel(staysOnTop) }
                        miniButton("aspectratio", label: L10n.text("Alterar tamanho da minicâmera"), action: resize)
                        Spacer(minLength: 0)
                        miniButton("arrow.up.left.and.arrow.down.right", label: L10n.text("Ampliar câmera"), action: expand)
                        miniButton("xmark", label: L10n.text("Fechar minicâmera"), action: close)
                    }.padding(6).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(8)
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.16), lineWidth: 0.75).allowsHitTesting(false))
            .preferredColorScheme(.dark)
            .onHover { hovering = $0 }
            .onAppear { session.start() }
            .onDisappear { session.stop(clear: true) }
            .onExitCommand(perform: close)
    }

    private func miniButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.text).frame(width: 28, height: 28).contentShape(RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).focusEffectDisabled().help(label).accessibilityLabel(label)
    }
}

/// Let the image move the window while leaving the control strip to SwiftUI.
private struct CameraWindowSurface: NSViewRepresentable {
    let showsControls: Bool
    func makeNSView(context: Context) -> SurfaceView {
        let view = SurfaceView()
        view.toolTip = L10n.text("Arraste a imagem para mover a minicâmera.")
        return view
    }
    func updateNSView(_ view: SurfaceView, context: Context) { view.showsControls = showsControls }
    final class SurfaceView: NSView {
        var showsControls = false
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = convert(point, from: superview)
            guard bounds.contains(local), !(showsControls && local.y < 56) else { return nil }
            return self
        }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}
