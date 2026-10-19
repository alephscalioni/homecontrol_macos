import HomeCore
import SwiftUI

struct CameraDetailView: View {
    @EnvironmentObject private var store: HomeStore
    @EnvironmentObject private var cameras: CameraManager
    let entity: HAEntity
    private var id: String { FavoriteControl(entity: entity, serverID: store.controlServerID).id }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let image = cameras.images[id].flatMap { NSImage(data: $0.data) }
            ZStack {
                Color.black.opacity(0.4)
                if let image { Image(nsImage: image).resizable().scaledToFit() }
                else {
                    VStack(spacing: 8) {
                        Image(systemName: "video").font(.system(size: 32, weight: .light))
                        Text(L10n.text("Uma imagem para conferir. Ao vivo para acompanhar.")).font(.system(size: 12))
                    }.foregroundStyle(Palette.secondary)
                }
            }.aspectRatio(16 / 9, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Button { Task { _ = try? await cameras.refresh(id: id) } } label: {
                    Label(L10n.text("Atualizar imagem"), systemImage: "arrow.clockwise")
                }.buttonStyle(TactileButtonStyle()).disabled(cameras.pending.contains(id) || !store.canUseSystemControls || entity.state == "off")
                Spacer()
                Button { cameras.openViewer?(id) } label: { Label(L10n.text("Ver ao vivo"), systemImage: "play.rectangle") }
                    .buttonStyle(TactileButtonStyle(prominent: true)).disabled(!store.canUseSystemControls || entity.state == "off")
            }
            if let error = cameras.errors[id] { Text(error).font(.system(size: 12)).foregroundStyle(Palette.warning) }
            if let value = cameras.images[id] {
                HStack { Text(L10n.text("Captura")); Text(value.capturedAt, style: .time) }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            Text(L10n.text("Você também pode escolher esta câmera ao editar um widget."))
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
        }.task(id: id) { _ = try? await cameras.refresh(id: id) }
    }
}

struct CameraViewer: View {
    @EnvironmentObject private var store: HomeStore
    @ObservedObject var session: CameraLiveSession
    let name: String
    let room: String?
    let makeMini: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "video.fill").foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.system(size: 16, weight: .semibold))
                    if let room { Text(room).font(.system(size: 12)).foregroundStyle(Palette.secondary) }
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let fresh = session.running && session.lastFrame.map { context.date.timeIntervalSince($0) < 5 } == true
                    Label(L10n.text(store.isDemo ? "Demonstração" : fresh ? "Ao vivo" : session.running ? "Conectando…" : "Pausado"), systemImage: fresh ? "circle.fill" : "circle")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(fresh ? Palette.good : Palette.secondary)
                }
                Button(action: makeMini) { Image(systemName: "pip") }
                    .buttonStyle(TactileButtonStyle()).focusEffectDisabled()
                    .accessibilityLabel(L10n.text("Abrir minicâmera"))
                    .help(L10n.text("Abrir minicâmera"))
                Button { session.running ? session.stop(clear: false) : session.start() } label: {
                    Label(L10n.text(session.running ? "Pausar" : "Conectar novamente"), systemImage: session.running ? "pause.fill" : "arrow.clockwise")
                }.buttonStyle(TactileButtonStyle()).focusEffectDisabled()
            }.padding(18)
            ZStack {
                Color.black
                if let image = session.image { Image(nsImage: image).resizable().scaledToFit() }
                else if session.running { ProgressView().controlSize(.large) }
                else { Image(systemName: "video.slash").font(.system(size: 48, weight: .light)).foregroundStyle(Palette.secondary) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .top, spacing: 8) {
                if session.error != nil { Image(systemName: "exclamationmark.circle").foregroundStyle(Palette.warning) }
                Text(session.error ?? L10n.text(store.isDemo ? "Sinal de exemplo. Nenhuma câmera real está sendo acessada." : "A qualidade e o atraso dependem da câmera e da conexão."))
                    .font(.system(size: 12)).foregroundStyle(session.error == nil ? Palette.secondary : Palette.warning)
                Spacer(minLength: 0)
            }.padding(14)
        }.foregroundStyle(Palette.text).background { NativeGlass() }.preferredColorScheme(.dark)
            .onAppear { session.start() }.onDisappear { session.stop(clear: true) }
    }
}
