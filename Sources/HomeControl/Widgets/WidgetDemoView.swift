import HomeCore
import SwiftUI

struct WidgetDemoView: View {
    @EnvironmentObject private var store: HomeStore
    @EnvironmentObject private var cameras: CameraManager
    var single = false
    @State private var selectedIDs: [String]
    init(single: Bool = false, camerasPreview: Bool = false) {
        self.single = single
        let defaults = camerasPreview ? (single ? ["camera.entrada_demo"] : ["camera.entrada_demo", "camera.jardim_demo", "climate.quarto", "light.sala"]) : single ? ["climate.quarto"] : ["climate.quarto", "light.sala", "switch.cafeteira", "scene.boa_noite"]
        let saved = camerasPreview ? defaults : UserDefaults.standard.stringArray(forKey: single ? "widgetPreview.item.demo" : "widgetPreview.items.demo") ?? defaults
        _selectedIDs = State(initialValue: Array(HomeWidgetSelection.identifiers(saved).prefix(single ? 1 : 4)))
    }
    private var limit: Int { single ? 1 : 4 }
    @State private var editing = false
    @State private var activatedScene: String?
    @State private var commandError: String?
    private var options: [HAEntity] {
        store.widgetEntities.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var items: [HomeWidgetItem] {
        HomeWidgetSelection.identifiers(selectedIDs).compactMap { id in
            guard let entity = options.first(where: { $0.id == id }) else { return nil }
            return HomeWidgetItem(FavoriteControl(entity: entity, serverID: store.controlServerID, room: store.areas[entity.id]))
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            previewContent.frame(width: 340, height: single ? 160 : 354)
                .background(WidgetInk.background.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.14), lineWidth: 0.75))
            HStack {
                Text(single ? L10n.text("Um aparelho") : L10n.format("%d de 4 itens", items.count)).font(.system(size: 11)).foregroundStyle(WidgetInk.secondary)
                Spacer()
                Button { editing.toggle() } label: { Label(L10n.text(single ? "Trocar item" : "Trocar itens"), systemImage: "arrow.triangle.2.circlepath") }
                    .buttonStyle(.bordered).controlSize(.small)
                    .popover(isPresented: $editing, arrowEdge: .bottom) {
                        WidgetSelectionEditor(single: single, selectedIDs: $selectedIDs, options: options) { editing = false }
                            .environmentObject(store)
                    }
            }.padding(.horizontal, 14).frame(height: 46).foregroundStyle(WidgetInk.text)
                .background(WidgetInk.background.opacity(0.94))
        }.frame(width: 340, height: single ? 206 : 400)
            .alert(L10n.text("Não foi possível enviar o comando"), isPresented: Binding(get: { commandError != nil }, set: { if !$0 { commandError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(commandError ?? "") }
            .task(id: selectedIDs) {
                for item in items where item.control?.isCamera == true { _ = try? await cameras.refresh(id: item.id) }
            }
            .onChange(of: selectedIDs) { _, value in
                UserDefaults.standard.set(value, forKey: single ? "widgetPreview.item.demo" : "widgetPreview.items.demo")
                activatedScene = nil
            }
    }

    @ViewBuilder private var previewContent: some View {
        if single, let item = items.first, let control = item.control {
            SingleDeviceWidgetCard(control: control, connected: true, demo: true, showsEditHint: false, camera: cameras.images[control.id]) {
                power(for: item)
            } adjustments: { adjustments(for: item, compact: false) }
        } else {
            HomeWidgetBoard(items: items, connected: true, demo: true) { item in
                HomeWidgetTile(item: item, connected: true, camera: cameras.images[item.id], demo: true) { power(for: item) }
                    adjustments: { adjustments(for: item, compact: true) }
            }
        }
    }

    @ViewBuilder private func power(for item: HomeWidgetItem) -> some View {

        if let control = item.control, let entity = store.entities.first(where: { $0.id == control.entityID }) {
            let pending = store.pendingEntities.contains(entity.id)
            if control.isCamera {
                HStack(spacing: 4) {
                    Button { perform(.refreshCamera(control.id)) } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(WidgetTemperatureButtonStyle(width: 28)).disabled(cameras.pending.contains(control.id))
                        .accessibilityLabel(L10n.format("Atualizar imagem de %@", control.name))
                    Button { perform(.openCamera(control.id)) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(WidgetTemperatureButtonStyle(width: 28))
                        .accessibilityLabel(L10n.format("Ver %@ ao vivo", control.name))
                }
            } else if let climate = control.climate {
                Button { perform(control.climate != nil ? .widgetPower(control.id, !entity.isOn) : .homeWidget(control.id, !entity.isOn)) } label: { Image(systemName: "power") }
                    .buttonStyle(WidgetPowerButtonStyle(isOn: entity.isOn))
                    .disabled(pending || !(entity.isOn ? climate.canPowerOff : climate.canPowerOn))
                    .accessibilityLabel(L10n.format(entity.isOn ? "Desligar %@" : "Ligar %@", entity.name))
            } else if control.kind == .scene {
                Button {
                    perform(.homeWidget(control.id, nil), scene: entity.id)
                } label: {
                    Label(L10n.text(activatedScene == entity.id ? "Ativada" : "Ativar"), systemImage: "play.fill")
                }.buttonStyle(HomeWidgetActionStyle(active: activatedScene == entity.id)).disabled(pending)
                    .accessibilityLabel(L10n.format("Ativar cena %@", entity.name))
            } else {
                Button { perform(control.climate != nil ? .widgetPower(control.id, !entity.isOn) : .homeWidget(control.id, !entity.isOn)) } label: {
                    Label(L10n.text(entity.isOn ? "Ligado" : "Desligado"), systemImage: "power")
                }.buttonStyle(HomeWidgetActionStyle(active: entity.isOn)).disabled(pending)
                    .accessibilityLabel(L10n.format(entity.isOn ? "Desligar %@" : "Ligar %@", entity.name))
            }
        }

    }

    @ViewBuilder private func adjustments(for item: HomeWidgetItem, compact: Bool) -> some View {

        if let control = item.control, let climate = control.climate,
           let entity = store.entities.first(where: { $0.id == control.entityID }) {
            HStack(spacing: compact ? 4 : 8) {
                Button { perform(.temperature(control.id, -1)) } label: { Image(systemName: "minus") }
                    .buttonStyle(WidgetTemperatureButtonStyle(width: compact ? 28 : 48)).disabled(store.pendingEntities.contains(entity.id) || !climate.canDecrease)
                    .accessibilityLabel(L10n.format("Diminuir temperatura de %@", entity.name))
                Button { perform(.temperature(control.id, 1)) } label: { Image(systemName: "plus") }
                    .buttonStyle(WidgetTemperatureButtonStyle(width: compact ? 28 : 48)).disabled(store.pendingEntities.contains(entity.id) || !climate.canIncrease)
                    .accessibilityLabel(L10n.format("Aumentar temperatura de %@", entity.name))
            }
        }

    }

    private func perform(_ action: ControlIntentBridge.Action, scene: String? = nil) {
        guard store.isDemo else { return }
        Task { @MainActor in
            do {
                try await ControlIntentBridge.perform(action)
                if let scene { activatedScene = scene }
            } catch { commandError = error.localizedDescription }
        }
    }

}

private struct WidgetSelectionEditor: View {
    @EnvironmentObject private var store: HomeStore
    let single: Bool
    @Binding var selectedIDs: [String]
    let options: [HAEntity]
    let onClose: () -> Void
    @State private var replacingID: String?
    @State private var search = ""
    private var replacementID: String? { single ? selectedIDs.first : replacingID }
    private var limit: Int { single ? 1 : 4 }

    private func move(_ id: String, by direction: Int) {
        guard let index = selectedIDs.firstIndex(of: id), selectedIDs.indices.contains(index + direction) else { return }
        selectedIDs.swapAt(index, index + direction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.text("Escolha seus controles")).font(.headline)
                Spacer()
                Text(single ? L10n.text("Um aparelho") : L10n.format("%d de 4 itens", selectedIDs.count)).font(.caption).foregroundStyle(.secondary)
            }
            Text(L10n.text(single ? "Escolha um aparelho ou cena na lista abaixo." : "Clique em Trocar ao lado do item que deseja substituir."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
            ForEach(Array(selectedIDs.enumerated()), id: \.element) { index, id in
                let name = options.first { $0.id == id }?.name ?? L10n.text("Item indisponível")
                HStack(spacing: 8) {
                    Text(name).font(.system(size: 12, weight: .medium)).lineLimit(2)
                    Spacer(minLength: 8)
                    Button(L10n.text("Trocar")) { replacingID = id; search = "" }
                        .tint(replacementID == id ? WidgetInk.accent : nil)
                        .accessibilityLabel(L10n.format("Trocar %@", name))
                    if !single {
                    Button { move(id, by: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0).accessibilityLabel(L10n.format("Mover %@ para cima", name))
                    Button { move(id, by: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == selectedIDs.count - 1).accessibilityLabel(L10n.format("Mover %@ para baixo", name))
                    }
                    Button { selectedIDs.removeAll { $0 == id }; if replacingID == id { replacingID = nil } } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel(L10n.format("Remover %@ do widget", name))
                }
            }
            Divider()
            TextField(L10n.text("Buscar aparelho ou cena"), text: $search).textFieldStyle(.roundedBorder)
            if let replacementID, let entity = options.first(where: { $0.id == replacementID }) {
                Text(L10n.format("Escolha abaixo o novo item para substituir %@.", entity.name))
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(WidgetInk.accent)
            } else if selectedIDs.count >= limit {
                Text(L10n.text("Para escolher outro, use Trocar ao lado de um item."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            let available = options.filter { !selectedIDs.contains($0.id) && HomeWidgetSelection.matches(FavoriteControl(entity: $0, serverID: store.controlServerID, room: store.areas[$0.id]), query: search) }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(available) { entity in
                        Button {
                            selectedIDs = HomeWidgetSelection.select(entity.id, replacing: replacementID, in: selectedIDs, limit: limit)
                            replacingID = nil
                            if single { onClose() }
                        } label: {
                            HStack {
                                let value = FavoriteControl(entity: entity, serverID: store.controlServerID, room: store.areas[entity.id])
                                Image(systemName: value.symbol).frame(width: 20).foregroundStyle(WidgetInk.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entity.name).font(.system(size: 12, weight: .medium))
                                    Text([HomeWidgetSelection.typeName(for: value), value.room].compactMap { $0 }.joined(separator: " · "))
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: replacementID == nil ? "plus.circle" : "arrow.triangle.2.circlepath")
                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()).padding(.vertical, 7)
                        }.buttonStyle(.plain).disabled(selectedIDs.count >= limit && replacementID == nil)
                            .accessibilityLabel(L10n.format(replacementID == nil ? "Adicionar %@ ao widget" : "Trocar o item por %@", entity.name))
                    }
                    if available.isEmpty {
                        Text(L10n.text("Nenhum aparelho encontrado. Tente outro nome, cômodo ou tipo."))
                            .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 20)
                    }
                }
            }.frame(height: 165)
            HStack {
                Text(L10n.text("Somente aparelhos de demonstração.")).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Pronto")) { onClose() }.keyboardShortcut(.defaultAction)
            }
        }.padding(18).frame(width: 450)
    }
}
