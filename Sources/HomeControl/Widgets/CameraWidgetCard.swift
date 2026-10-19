import HomeCore
import SwiftUI

/// A captured image, never labelled as live. WidgetKit controls timeline delivery.
struct CameraWidgetCard<Actions: View>: View {
    let control: FavoriteControl
    let connected: Bool
    var snapshot: CameraSnapshot?
    var compact = false
    var demo = false
    var showsEditHint = false
    @ViewBuilder let actions: () -> Actions
    private var media: CameraSnapshot? { snapshot ?? (try? CameraSnapshotStore.configured()?.read(id: control.id)) }
    var body: some View {
        let value = media
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            HStack(spacing: 5) {
                Image(systemName: "video.fill").foregroundStyle(WidgetInk.accent)
                Text(control.name).fontWeight(.semibold).lineLimit(1)
                Spacer(minLength: 0)
            }.font(.system(size: compact ? 11 : 13))
            GeometryReader { size in
                ZStack {
                    Color.black.opacity(0.45)
                    if let value, let image = NSImage(data: value.data) {
                        Image(nsImage: image).resizable().scaledToFill().frame(width: size.size.width, height: size.size.height).clipped().privacySensitive()
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "video.slash").font(.system(size: compact ? 17 : 22, weight: .light))
                            Text(L10n.text(connected && control.available ? "Atualize a imagem" : "Câmera indisponível"))
                                .font(.system(size: 10)).multilineTextAlignment(.center)
                        }.foregroundStyle(WidgetInk.secondary).padding(6)
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 8))
            }.accessibilityLabel(L10n.format("Imagem de %@", control.name))
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    if !connected || !control.available {
                        Text(L10n.text(!connected ? "Sem conexão" : "Indisponível"))
                    } else if demo { Text(L10n.text("Demonstração")) }
                    else if let value {
                        Text(L10n.text(Date().timeIntervalSince(value.capturedAt) > 120 ? "Imagem antiga" : "Captura"))
                    } else { Text(L10n.text("Sem imagem")) }
                    if let value { Text(value.capturedAt, style: .time).monospacedDigit() }
                }.font(.system(size: compact ? 9 : 10)).foregroundStyle(WidgetInk.secondary).lineLimit(1)
                Spacer(minLength: 0)
                actions()
            }.frame(height: 28)
            if showsEditHint { WidgetEditHint(multiple: false) }
        }.padding(compact ? 9 : 12).foregroundStyle(WidgetInk.text)
            .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: compact ? 14 : 0))
    }
}
