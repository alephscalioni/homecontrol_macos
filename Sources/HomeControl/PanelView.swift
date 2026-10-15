import SwiftUI
import HomeCore

struct PanelView: View {
    @EnvironmentObject private var store: HomeStore
    @EnvironmentObject private var updater: AppUpdater
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        VStack(spacing: 0) {
            header
            if store.showSettings {
                SetupView()
            } else {
                ScrollView {
                    if store.category == .rooms {
                        RoomsView()
                    } else if [.climate, .lights, .fans, .covers].contains(store.category), let entity = store.selected {
                        VStack(spacing: 12) {
                            if store.category == .climate && !store.detailFromRoom && !store.detailFromFavorites && store.filtered.count > 1 {
                                Picker("Ar-condicionado", selection: Binding(get: { store.selected?.id ?? "" }, set: { store.selection[.climate] = $0 })) {
                                    ForEach(store.filtered) { item in Text(store.areas[item.id] ?? item.name).tag(item.id) }
                                }.pickerStyle(.segmented).controlSize(.small).labelsHidden().padding(.bottom, 4)
                            }
                            deviceHeader(entity)
                            DeviceDetail(entity: entity)
                                .disabled(!store.canControl || !entity.available || store.pendingEntities.contains(entity.id))
                            if !entity.available {
                                Text("Aparelho indisponível no Home Assistant.").font(.system(size: 12)).foregroundStyle(Palette.warning)
                            }
                        }.padding(20).padding(.top, 2)
                    } else {
                        DeviceListView()
                    }
                }.scrollIndicators(.hidden)
            }
            Spacer(minLength: 0)
            if let message = store.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle").padding(.top, 1)
                    ScrollView { Text(message).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }
                        .frame(maxHeight: 64)
                    IconButton(icon: "xmark", label: "Fechar aviso", size: 20) { store.errorMessage = nil }
                }.font(.system(size: 11)).foregroundStyle(Palette.warning).padding(12)
                    .background(Palette.warning.opacity(0.08))
            }
            footer
        }
        .frame(width: 440, height: 632)
        .background {
            if reduceTransparency { Palette.background }
            else { NativeGlass() }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
            LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0.07), .white.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.75))
        .foregroundStyle(Palette.text)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "house.fill").foregroundStyle(Palette.accent).font(.system(size: 13))
                Text("HomeControl").font(.system(size: 12, weight: .semibold))
                Spacer()
                if store.isDemo {
                    Text("Demonstração").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.accent)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Palette.surface, in: Capsule())
                }
                Menu {
                    Button("Conectar ao Home Assistant…") { store.showSettings = true }
                    if store.phase == .connected || store.phase == .reconnecting { Button("Reconectar") { store.retryNow() } }
                    if updater.isConfigured {
                        Divider()
                        Button("Verificar atualizações…") { updater.checkForUpdates() }.disabled(!updater.canCheckForUpdates)
                    }
                    Divider()
                    Button("Sair do HomeControl") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Menu do HomeControl")
            }
            if !store.showSettings {
                HStack(spacing: 3) {
                    ForEach([DeviceCategory.climate, .rooms, .favorites]) { category in
                        Button { store.showCategory(category) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon).font(.system(size: 13))
                                Text(category.title).font(.system(size: 11, weight: store.topCategory == category ? .semibold : .regular))
                            }.frame(maxWidth: .infinity).frame(height: 34)
                                .foregroundStyle(store.topCategory == category ? Palette.text : Palette.secondary)
                                .background(store.topCategory == category ? Palette.raised : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).help(category.title).accessibilityLabel(category.title)
                            .accessibilityAddTraits(store.topCategory == category ? .isSelected : [])
                    }
                }
            }
        }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, store.showSettings ? 8 : 10)
    }

    private func deviceHeader(_ entity: HAEntity) -> some View {
        HStack(spacing: 8) {
            if store.detailFromRoom || store.detailFromFavorites || store.category != .climate {
                IconButton(icon: "chevron.left", label: store.detailFromFavorites ? "Voltar aos favoritos" : "Voltar ao cômodo", size: 28) { store.returnToRoom() }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(entity.name).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                HStack(spacing: 5) {
                    if let room = store.areas[entity.id] { Text(room) }
                    if entity.domain == "climate" {
                        Image(systemName: "thermometer.medium").foregroundStyle(Palette.accent)
                        Text("Ambiente \(displayNumber(entity.number("current_temperature")))\(entity.temperatureUnit)")
                    }
                }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            IconButton(icon: store.favoriteIDs.contains(entity.id) ? "star.fill" : "star", label: "Favoritar \(entity.name)", active: store.favoriteIDs.contains(entity.id), size: 30) { store.toggleFavorite(entity) }
            if ServiceCall.power(entity) != nil || entity.domain == "climate" {
                Button { store.execute(ServiceCall.power(entity)) } label: {
                    ZStack {
                        Circle().fill(entity.isOn ? Palette.accent.opacity(0.12) : Palette.surface)
                        Circle().stroke(entity.isOn ? Palette.accent.opacity(0.48) : Palette.line, lineWidth: 1)
                        if store.pendingEntities.contains(entity.id) { ProgressView().controlSize(.small) }
                        else { Image(systemName: "power").font(.system(size: 23, weight: .light)).foregroundStyle(entity.isOn ? Palette.accent : Palette.secondary) }
                    }.frame(width: 42, height: 42)
                }.buttonStyle(.plain).disabled(!store.canControl || !entity.available || ServiceCall.power(entity) == nil || store.pendingEntities.contains(entity.id))
                    .accessibilityLabel("\(entity.isOn ? "Desligar" : "Ligar") \(entity.name)")
                    .help(ServiceCall.power(entity) == nil ? "Escolha um modo para ligar este aparelho" : (entity.isOn ? "Desligar" : "Ligar"))
            }
        }.frame(minHeight: 48)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            if store.isConnecting { ProgressView().controlSize(.mini) }
            else { Circle().fill(store.phase == .connected ? Palette.good : Palette.accent).frame(width: 5, height: 5) }
            Text(store.feedback ?? store.statusLabel).font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
            Spacer(minLength: 2)
            if store.phase == .reconnecting {
                Button("Tentar agora") { store.retryNow() }.font(.system(size: 10)).buttonStyle(.plain)
            }
            IconButton(icon: store.showSettings ? "chevron.left" : "slider.horizontal.3", label: store.showSettings ? "Voltar aos controles" : "Configurações", size: 26) {
                if store.showSettings && store.entities.isEmpty { store.useDemo() }
                else { store.showSettings.toggle() }
            }
        }.padding(.horizontal, 20).padding(.vertical, 10)
            .background(Palette.surface.opacity(0.3))
    }
}
