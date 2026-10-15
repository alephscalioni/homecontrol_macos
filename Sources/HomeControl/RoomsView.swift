import SwiftUI
import HomeCore

struct RoomsView: View {
    @EnvironmentObject private var store: HomeStore
    var body: some View {
        if let scope = store.roomScope {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Button { store.roomScope = nil } label: {
                        Label(L10n.text("Cômodos"), systemImage: "chevron.left").font(.system(size: 11, weight: .medium))
                    }.buttonStyle(.plain).foregroundStyle(Palette.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(store.roomName(for: scope)).font(.system(size: 27, weight: .medium, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Text(dailyCount(store.everydayItems(in: scope).count)).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                    if scope == .unassigned {
                        Text(L10n.text("Aparelhos que ainda precisam de um cômodo no Home Assistant. Consumo e ajustes ficam nos grupos do menu abaixo."))
                            .font(.system(size: 11)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if scope == .general {
                        Text(L10n.text("Cenas e serviços que pertencem à casa toda.")).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                    metadataWarning
                }.padding(.horizontal, 20).padding(.top, 8)
                DeviceListView(scope: scope, showsHeading: false)
            }
        } else {
            overview
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("Cômodos")).font(.system(size: 27, weight: .medium, design: .rounded))
                    Text(syncLabel).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Button(L10n.text("Toda a casa")) { store.roomScope = .all }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(Palette.accent)
                if store.registryLoading { ProgressView().controlSize(.small).padding(8) }
                else {
                    IconButton(icon: "arrow.clockwise", label: L10n.text("Atualizar cômodos"), size: 30) { store.refreshAreas() }
                        .disabled(store.phase != .connected)
                }
            }
            metadataWarning
            if !store.registryLoaded {
                VStack(spacing: 13) {
                    if store.registryLoading || store.isConnecting { ProgressView().padding(12) }
                    else { Image(systemName: "house").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(Palette.accent) }
                    Text(store.registryLoading || store.isConnecting ? L10n.text("Carregando a organização da casa…") : L10n.text("Cômodos indisponíveis"))
                        .font(.system(size: 15, weight: .medium)).multilineTextAlignment(.center)
                    Text(L10n.text("Ar-condicionado e Favoritos continuam disponíveis nas abas acima."))
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                    if store.phase == .connected { Button(L10n.text("Tentar novamente")) { store.refreshAreas() }.buttonStyle(TactileButtonStyle()) }
                }.padding(.vertical, 45).frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.registryAreas) { area in
                        roomRow(scope: .area(area.id), name: area.name, icon: roomIcon(area.name))
                        Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 43)
                    }
                    if !store.items(in: .general).isEmpty { roomRow(scope: .general, name: L10n.text("Geral da casa"), icon: "house.lodge") }
                    if !store.items(in: .unassigned).isEmpty { roomRow(scope: .unassigned, name: L10n.text("Sem cômodo"), icon: "square.dashed") }
                }
                if store.registryAreas.isEmpty {
                    Text(L10n.text("Ainda não há cômodos cadastrados no Home Assistant. Você pode acessar todos os itens acima."))
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }.padding(20).padding(.top, 2)
    }
    @ViewBuilder private var metadataWarning: some View {
        if let message = store.metadataNotice {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.system(size: 11)).foregroundStyle(Palette.warning).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var syncLabel: String {
        if store.isDemo { return L10n.text("Cômodos e itens de exemplo") }
        if store.registryLoading && !store.registryLoaded { return L10n.text("Lendo o Home Assistant…") }
        if store.phase == .reconnecting || store.phase == .disconnected { return L10n.text("Última organização recebida") }
        return store.registryRealtime ? L10n.text("Sincronização automática com o Home Assistant") : L10n.text("Atualização automática a cada minuto")
    }
    private func roomRow(scope: RoomScope, name: String, icon: String) -> some View {
        let count = store.everydayItems(in: scope).count
        let additional = store.items(in: scope).filter { !store.isHidden($0) && !store.purpose(of: $0).isEveryday }.count
        return Button { store.roomScope = scope } label: {
            HStack(spacing: 13) {
                Image(systemName: icon).font(.system(size: 23, weight: .light)).foregroundStyle(Palette.accent).frame(width: 30)
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    Text(dailyCount(count) + (additional > 0 ? L10n.format(" · %ld em outros grupos", additional) : "")).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }.padding(.vertical, 12).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(L10n.format("Abrir %@, %@", name, dailyCount(count)))
    }
    private func dailyCount(_ count: Int) -> String {
        count == 1 ? L10n.text("1 item de uso diário") : L10n.format("%ld itens de uso diário", count)
    }
    private func roomIcon(_ name: String) -> String {
        let name = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        if name.contains("cozinha") || name.contains("kitchen") { return "fork.knife" }
        if name.contains("jantar") || name.contains("dining") { return "table.furniture" }
        if name.contains("sala") || name.contains("living") { return "sofa" }
        if name.contains("quarto") || name.contains("suite") || name.contains("bedroom") { return "bed.double" }
        if name.contains("escritorio") || name.contains("office") { return "desktopcomputer" }
        if name.contains("lavanderia") || name.contains("laundry") { return "washer" }
        if name.contains("sacada") || name.contains("varanda") || name.contains("balcony") { return "sun.max" }
        if name.contains("entrada") || name.contains("entry") || name.contains("entrance") { return "door.left.hand.open" }
        return "square.grid.2x2"
    }
}
