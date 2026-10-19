import SwiftUI
import HomeCore

struct VacuumDetailView: View {
    @EnvironmentObject private var store: HomeStore
    let entity: HAEntity
    var body: some View {
        let members = store.vacuumItems(for: entity)
        let sections = Dictionary(uniqueKeysWithValues: members.map { item in
            (item.id, VacuumOrganization.section(for: item, entry: store.registryEntries[item.id], override: store.organization.purposes[item.id]))
        })
        VacuumDetailContent(entity: entity, members: members, sections: sections)
    }
}

private struct VacuumDetailContent: View {
    @EnvironmentObject private var store: HomeStore
    let entity: HAEntity
    let members: [HAEntity]
    let sections: [String: VacuumSection]
    @State private var search = ""
    @State private var expanded: Set<VacuumSection> = []
    @State private var roomsOnly = false
    @State private var selectedRooms: Set<String> = []
    private var roomMap: VacuumRoomMap? { members.compactMap { VacuumRoomMap(entity: $0) }.first }
    private var roomAction: HAEntity? { members.first { $0.domain == "notify" && VacuumOrganization.has($0, ["start_vacuum_room_sweep"]) } }
    private var roomCommand: ServiceCall? {
        guard let map = roomMap, let action = roomAction else { return nil }
        return map.command(selectedIDs: selectedRooms, action: action, entry: store.registryEntries[action.id])
    }
    private var searching: Bool { !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var results: [HAEntity] {
        guard searching else { return members }
        let terms = search.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).split(whereSeparator: \.isWhitespace)
        return members.filter { item in
            let text = [item.name, item.id, title(item), section(item).title].joined(separator: " ").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return terms.allSatisfy { text.contains($0) }
        }
    }
    private var primary: [HAEntity] {
        Array(members.filter { VacuumOrganization.isPrimarySetting($0) && store.organization.purposes[$0.id] == nil }.prefix(4))
    }
    private var dockSettings: [HAEntity] {
        members.filter { $0.domain == "select" && VacuumOrganization.has($0, ["auto_dust_arrest_power_level", "water_output_for_washing_mop"]) && store.organization.purposes[$0.id] == nil }
    }
    private var standardSuction: Bool {
        !primary.contains(where: VacuumOrganization.isSuctionSetting) && entity.options("fan_speed_list").contains { VacuumOrganization.suction(entity, speed: $0) != nil }
    }
    private func section(_ item: HAEntity) -> VacuumSection {
        sections[item.id] ?? .advanced
    }
    private func values(_ group: VacuumSection) -> [HAEntity] {
        let primaryIDs = Set((primary + dockSettings).map(\.id))
        return results.filter { section($0) == group && (searching || !primaryIDs.contains($0.id)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            status
            if roomMap != nil && roomAction != nil { roomSelection }
            HStack(spacing: 8) {
                Button {
                    if entity.state == "cleaning" { store.execute(VacuumAction.pause.command(for: entity)) }
                    else if roomsOnly && entity.state != "paused" { store.execute(roomCommand) }
                    else { store.execute(VacuumAction.start.command(for: entity)) }
                } label: {
                    Label(startTitle, systemImage: entity.state == "cleaning" ? "pause.fill" : "play.fill").frame(maxWidth: .infinity)
                }.buttonStyle(TactileButtonStyle(prominent: true)).disabled(!canStart)
                action(.returnToBase, title: L10n.text("Voltar à base"), icon: "house")
                if entity.state == "cleaning" || entity.state == "paused" || entity.state == "returning" {
                    action(.stop, title: L10n.text("Parar"), icon: "stop.fill")
                }
            }.font(.system(size: 12, weight: .medium))
            activitySummary
            if !primary.isEmpty || standardSuction {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    if standardSuction {
                        OptionTile(icon: "wind", title: L10n.text("Sucção"), value: entity.text("fan_speed") ?? "—", options: entity.options("fan_speed_list")) {
                            store.execute(VacuumOrganization.suction(entity, speed: $0))
                        }.disabled(!canEdit(entity))
                    }
                    ForEach(primary) { item in
                        OptionTile(icon: primaryIcon(item), title: title(item), value: value(item), options: item.options("options")) {
                            store.execute(VacuumOrganization.setting(item, option: $0))
                        }.disabled(!canEdit(item))
                    }
                }
            }
            if !dockButtons.isEmpty || !dockSettings.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text(L10n.text("Cuidados com a base")).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(dockButtons, id: \.entity.id) { pair in
                            Button { store.execute(pair.action.command(for: pair.entity)) } label: {
                                Label(pair.action.title, systemImage: pair.action.icon).frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(TactileButtonStyle()).font(.system(size: 11)).disabled(!canEdit(pair.entity))
                        }
                    }
                    if !dockSettings.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(dockSettings) { item in
                                OptionTile(icon: VacuumOrganization.has(item, ["auto_dust_arrest_power_level"]) ? "wind" : "drop", title: title(item), value: value(item), options: item.options("options")) {
                                    store.execute(VacuumOrganization.setting(item, option: $0))
                                }.disabled(!canEdit(item))
                            }
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                TextField(L10n.text("Buscar ajustes do aspirador"), text: $search).textFieldStyle(.plain)
                    .accessibilityLabel(L10n.text("Buscar ajustes do aspirador"))
                if searching { IconButton(icon: "xmark.circle.fill", label: L10n.text("Limpar busca"), size: 20) { search = "" } }
            }.font(.system(size: 12)).padding(11).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                ForEach(VacuumSection.allCases) { group in
                    let items = values(group)
                    if !items.isEmpty { disclosure(group, items: items) }
                }
            }
            if searching && results.isEmpty {
                Text(L10n.text("Nenhum resultado")).font(.system(size: 12)).foregroundStyle(Palette.secondary)
            }
            if VacuumAction.locate.command(for: entity) != nil {
                Button { store.execute(VacuumAction.locate.command(for: entity)) } label: {
                    Label(L10n.text("Localizar aspirador"), systemImage: "speaker.wave.2")
                }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.secondary).disabled(!canEdit(entity))
            }
        }
        .onAppear { search = store.vacuumDetailQuery }
        .onChange(of: entity.id) { _, _ in search = store.vacuumDetailQuery; expanded = []; selectedRooms = []; roomsOnly = false }
        .onChange(of: roomMap?.mapID) { _, _ in selectedRooms = []; roomsOnly = false }
        .onChange(of: roomMap?.rooms.map(\.id)) { _, ids in selectedRooms.formIntersection(Set(ids ?? [])) }
        .onChange(of: store.vacuumDetailQuery) { _, value in search = value }
    }
    private var startTitle: String {
        if entity.state == "cleaning" { return L10n.text("Pausar") }
        if entity.state == "paused" { return L10n.text("Retomar") }
        if roomsOnly { return L10n.format("Limpar (%ld)", selectedRooms.count) }
        return L10n.text("Limpar tudo")
    }
    private var canStart: Bool {
        guard canEdit(entity) else { return false }
        if entity.state == "cleaning" { return VacuumAction.pause.command(for: entity) != nil }
        if entity.state == "paused" { return VacuumAction.start.command(for: entity) != nil }
        if roomsOnly { return roomCommand != nil && roomAction.map(canEdit) == true && !["cleaning", "returning"].contains(entity.state) }
        return VacuumAction.start.command(for: entity) != nil
    }
    private var roomSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 3) {
                ForEach([false, true], id: \.self) { rooms in
                    Button { roomsOnly = rooms } label: {
                        Text(rooms ? L10n.text("Escolher cômodos") : L10n.text("Toda a casa"))
                            .font(.system(size: 12, weight: roomsOnly == rooms ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(roomsOnly == rooms ? Palette.raised : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(rooms ? L10n.text("Escolher cômodos") : L10n.text("Toda a casa"))
                        .accessibilityAddTraits(roomsOnly == rooms ? .isSelected : [])
                }
            }.padding(3).background(Palette.surface, in: RoundedRectangle(cornerRadius: 11))
            if roomsOnly, let map = roomMap {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                    ForEach(map.rooms) { room in
                        Button {
                            if selectedRooms.contains(room.id) { selectedRooms.remove(room.id) } else { selectedRooms.insert(room.id) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedRooms.contains(room.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(Palette.accent)
                                Text(room.name.isEmpty ? L10n.format("Cômodo %@", room.id) : room.name).font(.system(size: 12)).lineLimit(2)
                                Spacer(minLength: 0)
                            }.padding(10).frame(maxWidth: .infinity, minHeight: 42).background(selectedRooms.contains(room.id) ? Palette.raised : Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).accessibilityAddTraits(selectedRooms.contains(room.id) ? .isSelected : [])
                    }
                }
                Text(L10n.text("Os nomes acompanham o mapa do aspirador. Renomeou no aplicativo? Eles atualizam quando chegarem ao Home Assistant."))
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var dockButtons: [(action: VacuumDockAction, entity: HAEntity)] {
        VacuumDockAction.allCases.compactMap { action in
            // Multiple aliases can expose the same operation. Present one control.
            let aliases = members.filter { action.matches($0) }
            guard let item = aliases.first(where: \.available) ?? aliases.first else { return nil }
            return (action, item)
        }.filter { ![.stopWash, .stopDry, .stopCleanBase, .emptyWater].contains($0.action) }
    }
    private var activitySummary: some View {
        let fields = members.filter { $0.available && VacuumOrganization.has($0, ["cleaning_time", "cleaning_progress", "cleaning_area"]) }
        return HStack(alignment: .top, spacing: 12) {
            ForEach(fields) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(title(item)).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    Text(summaryValue(item)).font(.system(size: 17, weight: .medium, design: .rounded)).monospacedDigit()
                    if VacuumOrganization.has(item, ["cleaning_area"]), item.text("unit_of_measurement") == nil {
                        Text(L10n.text("Unidade não informada")).font(.system(size: 9)).foregroundStyle(Palette.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(.vertical, fields.isEmpty ? 0 : 4)
    }
    private func summaryValue(_ item: HAEntity) -> String {
        if VacuumOrganization.has(item, ["cleaning_time"]), item.text("unit_of_measurement") == "s", let seconds = Double(item.state), seconds.isFinite {
            return displayNumber(seconds / 60) + " min"
        }
        return value(item)
    }
    private var status: some View {
        HStack(spacing: 16) {
            Image(systemName: "robotic.vacuum").font(.system(size: 59, weight: .ultraLight))
                .foregroundStyle(entity.available ? Palette.accent : Palette.secondary).frame(width: 78, height: 82).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(robotState).font(.system(size: 25, weight: .medium, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                if let battery = battery {
                    Label("\(displayNumber(battery))%", systemImage: "battery.100percent")
                        .font(.system(size: 13)).foregroundStyle(Palette.secondary).monospacedDigit()
                        .accessibilityLabel(L10n.format("Bateria: %@%%", displayNumber(battery)))
                }
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var battery: Double? {
        let reading = entity.number("battery_level") ?? members.first { $0.available && ($0.text("device_class") == "battery" || VacuumOrganization.has($0, ["battery_level", "bateria"])) }.flatMap { Double($0.state) }
        guard let reading, reading.isFinite, (0...100).contains(reading) else { return nil }
        return reading
    }
    private var robotState: String {
        switch entity.state {
        case "docked": return L10n.text("Na base")
        case "cleaning": return L10n.text("Limpando")
        case "returning": return L10n.text("Voltando à base")
        case "paused": return L10n.text("Pausado")
        case "error": return L10n.text("Precisa de atenção")
        default: return displayName(entity.state)
        }
    }
    private func action(_ action: VacuumAction, title: String, icon: String, prominent: Bool = false) -> some View {
        Button { store.execute(action.command(for: entity)) } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.85)
        }.buttonStyle(TactileButtonStyle(prominent: prominent))
            .disabled(!canEdit(entity) || action.command(for: entity) == nil)
    }
    private func canEdit(_ item: HAEntity) -> Bool {
        store.canUseSystemControls && entity.available && item.available &&
            !VacuumOrganization.isBusy(robotID: entity.id, owners: store.vacuumOwners, pendingIDs: store.pendingEntities)
    }
    private func disclosure(_ group: VacuumSection, items: [HAEntity]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if expanded.contains(group) { expanded.remove(group) } else { expanded.insert(group) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: group.icon).foregroundStyle(Palette.accent).frame(width: 18)
                    Text(group.title).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(items.count)").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    Image(systemName: searching || expanded.contains(group) ? "chevron.down" : "chevron.right").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(group.title)
                .accessibilityValue(searching || expanded.contains(group) ? L10n.text("Expandido") : L10n.text("Recolhido"))
            if searching || expanded.contains(group) {
                VStack(alignment: .leading, spacing: 0) {
                    if group == .advanced {
                        Text(L10n.text("Mapas, comandos internos e dados técnicos. Para alterações avançadas, use o Home Assistant."))
                            .font(.system(size: 11)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true).padding(.vertical, 10)
                        Button(L10n.text("Abrir no Home Assistant")) { openHomeAssistant() }
                            .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.accent).padding(.bottom, 12)
                    }
                    ForEach(items) { item in
                        settingRow(item)
                        if item.id != items.last?.id { Rectangle().fill(Palette.line).frame(height: 1) }
                    }
                }.padding(.leading, 28)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
        }
    }
    private func settingRow(_ item: HAEntity) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text(title(item)).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                if let action = VacuumDockAction.allCases.first(where: { $0.matches(item) }) {
                    Button { store.execute(action.command(for: item)) } label: { Text(action.title).font(.system(size: 11)) }
                        .buttonStyle(TactileButtonStyle()).disabled(!canEdit(item))
                } else if item.domain == "switch", section(item) != .advanced {
                    Toggle(title(item), isOn: Binding(get: { item.state == "on" }, set: { _ in store.execute(ServiceCall.power(item)) }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Palette.accent).disabled(!canEdit(item))
                } else if item.domain == "select", section(item) != .advanced {
                    Menu {
                        ForEach(item.options("options"), id: \.self) { option in
                            Button { store.execute(VacuumOrganization.setting(item, option: option)) } label: {
                                if item.state == option { Label(displayName(option), systemImage: "checkmark") }
                                else { Text(displayName(option)) }
                            }
                        }
                    } label: { Text(value(item)).lineLimit(2).frame(maxWidth: 135, alignment: .trailing) }
                        .menuStyle(.borderlessButton).fixedSize(horizontal: false, vertical: true).font(.system(size: 12)).disabled(!canEdit(item))
                } else {
                    Text(value(item)).font(.system(size: 12, weight: .medium)).monospacedDigit().foregroundStyle(Palette.secondary)
                        .lineLimit(2).frame(maxWidth: 135, alignment: .trailing)
                }
                IconButton(icon: store.favoriteIDs.contains(item.id) ? "star.fill" : "star", label: L10n.format("Favoritar %@", title(item)), active: store.favoriteIDs.contains(item.id), size: 22) { store.toggleFavorite(item) }
            }
            if item.domain == "number", section(item) != .advanced, let bounds = VacuumOrganization.numberBounds(item), let current = Double(item.state), current.isFinite {
                ControlSlider(label: title(item), value: current, bounds: bounds, step: item.number("step") ?? 1, unit: item.text("unit_of_measurement") ?? "", showButtons: true) {
                    store.execute(VacuumOrganization.setting(item, number: $0))
                }.disabled(!canEdit(item))
            }
        }.padding(.vertical, 12)
    }
    private func value(_ item: HAEntity) -> String {
        if item.state == "unavailable" { return L10n.text("Indisponível") }
        if ["button", "text", "event", "notify"].contains(item.domain) { return L10n.text("No Home Assistant") }
        if item.state.isEmpty || item.state.hasPrefix("{") || item.state.hasPrefix("[") { return L10n.text("Dados técnicos") }
        if item.state == "unknown" { return L10n.text("Sem leitura") }
        if let number = Double(item.state), number.isFinite {
            return displayNumber(number) + (item.text("unit_of_measurement").map { " " + $0 } ?? "")
        }
        return displayName(item.state)
    }
    private func title(_ item: HAEntity) -> String {
        if let action = VacuumDockAction.allCases.first(where: { $0.matches(item) }) { return action.title }
        if VacuumOrganization.isSuctionSetting(item) { return L10n.text("Sucção") }
        let labels: [(String, String)] = [
            ("sweep_mop_type", "Modo de limpeza"), ("cleaning_mode", "Modo de limpeza"), ("clean_times", "Passadas"),
            ("mop_water_output_level", "Água no pano"), ("water_output_for_mopping", "Água no pano"), ("water_level", "Água no pano"),
            ("carpet_boost", "Reforço em tapetes"), ("carpet_avoidance", "Evitar tapetes"),
            ("carpet_cleaning_method", "Limpeza de tapetes"), ("sweep_route", "Rota de limpeza"), ("obstacle_avoidance_strategy", "Desvio de obstáculos"),
            ("auto_dust_arrest", "Esvaziamento automático"), ("auto_mop_dry", "Secagem automática"), ("enable_mop_wash", "Lavar o pano"),
            ("hot_water_mop_wash", "Lavagem com água quente"), ("wash_mop_water_temperature", "Temperatura de lavagem"), ("drying_time", "Duração da secagem"),
            ("water_output_for_washing_mop", "Água na lavagem"), ("frequency_mop_wash", "Frequência de lavagem"), ("frequency_mop_wash_by_time", "Intervalo de lavagem"),
            ("mop_auto_lift", "Elevar o pano"), ("use_detergent", "Usar detergente"), ("no_disturb", "Não perturbe"), ("do_not_disturb", "Não perturbe"), ("volume", "Volume"),
            ("battery_level", "Bateria"), ("charging_state", "Carregamento"), ("brush_life_level", "Vida útil da escova"), ("filter_life_level", "Vida útil do filtro"),
            ("mop_life_level", "Vida útil do pano"), ("dust_bag_life_level", "Vida útil do saco de pó"), ("detergent_left_level", "Detergente restante"),
            ("cleaning_time", "Tempo de limpeza"), ("cleaning_area", "Área informada"), ("cleaning_progress", "Progresso"),
            ("auto_dust_arrest_power_level", "Força do esvaziamento"), ("dust_arrest_frequency", "Frequência do esvaziamento"),
            ("sewage_tank_status", "Tanque de água suja"), ("water_tank_status", "Tanque de água limpa"), ("device_fault", "Código de falha")
        ]
        if let label = labels.first(where: { VacuumOrganization.has(item, [$0.0]) }) { return L10n.text(label.1) }
        return VacuumOrganization.shortName(item, deviceName: store.deviceName(for: item))
    }
    private func primaryIcon(_ item: HAEntity) -> String {
        if VacuumOrganization.has(item, ["clean_times"]) { return "repeat" }
        if VacuumOrganization.has(item, ["mop_water_output_level", "water_level", "water_output_for_mopping"]) { return "drop" }
        if VacuumOrganization.isSuctionSetting(item) { return "wind" }
        return "slider.horizontal.3"
    }
    private func openHomeAssistant() {
        guard var url = try? ServerAddress.normalize(store.serverAddress) else { return }
        if let deviceID = store.registryEntries[entity.id]?.deviceID {
            url.appendPathComponent("config/devices/device/" + deviceID)
        }
        NSWorkspace.shared.open(url)
    }
}
