import SwiftUI
import HomeCore

struct DeviceListView: View {
    @EnvironmentObject private var store: HomeStore
    var scope: RoomScope? = nil
    var showsHeading = true
    @State private var search = ""
    @State private var room = ""
    @State private var organizing = false
    @State private var expanded: Set<String> = []
    private var base: [HAEntity] {
        (scope.map { store.items(in: $0) } ?? store.categoryItems).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var results: [HAEntity] {
        let values = organizing || !search.isEmpty || store.category == .favorites ? base : store.consolidatedItems(base)
        return values.filter { entity in
            !store.isHidden(entity) && (search.isEmpty || HomeWidgetSelection.matches(FavoriteControl(entity: entity, serverID: store.controlServerID, room: store.areas[entity.id]), query: search))
        }
    }
    private var hiddenItems: [HAEntity] { base.filter { store.isHidden($0) } }
    private func items(_ purpose: EntityPurpose) -> [HAEntity] { results.filter { store.purpose(of: $0) == purpose } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                if showsHeading {
                    Text(store.category.title).font(.system(size: 26, weight: .medium, design: .rounded))
                }
                Spacer()
                Button(organizing ? L10n.text("Concluir") : L10n.text("Organizar")) { organizing.toggle() }
                    .font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(Palette.accent)
                    .accessibilityLabel(organizing ? L10n.text("Concluir organização") : L10n.text("Organizar itens"))
            }
            if #available(macOS 26.0, *), store.category == .favorites, !organizing {
                Text(L10n.text("No Central de Controle, clique em Editar Controles e procure HomeControl."))
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if organizing {
                Text(L10n.text("Use o menu de cada item para mudar seu grupo ou ocultá-lo neste Mac."))
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if base.count > 6 {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                    TextField("", text: $search).textFieldStyle(.plain).accessibilityLabel(L10n.text("Buscar item"))
                        .overlay(alignment: .leading) {
                            if search.isEmpty { Text(scope == nil ? L10n.text("Buscar item") : L10n.text("Buscar neste cômodo")).foregroundStyle(Palette.secondary).allowsHitTesting(false).accessibilityHidden(true) }
                        }
                    if !search.isEmpty { IconButton(icon: "xmark.circle.fill", label: L10n.text("Limpar busca"), size: 20) { search = "" } }
                }.font(.system(size: 12)).padding(12).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            }
            if results.isEmpty {
                VStack(spacing: 13) {
                    Image(systemName: store.category == .favorites ? "star" : "house").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(Palette.accent)
                    Text(emptyTitle).font(.system(size: 16, weight: .medium))
                    Text(emptyDescription).font(.system(size: 12)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
                }.padding(.vertical, 38).frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(EntityPurpose.allCases.filter(\.isEveryday)) { purpose in
                        if !items(purpose).isEmpty { itemGroup(title: purpose.title, items: items(purpose)) }
                    }
                    ForEach(EntityPurpose.allCases.filter { !$0.isEveryday }) { purpose in
                        let values = items(purpose)
                        if !values.isEmpty {
                            if !search.isEmpty || store.category == .favorites {
                                itemGroup(title: purpose.title, items: values)
                            } else {
                                expandable(purpose.title, icon: purpose.icon, count: values.count, key: purpose.rawValue) {
                                    if purpose == .consumption {
                                        VStack(alignment: .leading, spacing: 18) {
                                            ForEach(ConsumptionMetric.allCases) { metric in
                                                let measurements = values.filter { ConsumptionMetric.classify($0) == metric }
                                                if !measurements.isEmpty { itemGroup(title: metric.title, items: measurements) }
                                            }
                                        }.padding(.top, 14)
                                    } else {
                                        itemRows(values).padding(.top, 6)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if organizing && !hiddenItems.isEmpty {
                expandable(L10n.text("Itens ocultos"), icon: "eye.slash", count: hiddenItems.count, key: "hidden") { itemRows(hiddenItems).padding(.top, 6) }
            }
        }.padding(.horizontal, 20).padding(.bottom, 20).padding(.top, showsHeading ? 20 : 0)
            .onChange(of: scope) { _, _ in search = ""; expanded = []; organizing = false }
            .onChange(of: store.category) { _, _ in search = ""; expanded = []; organizing = false }
    }
    private func expandable<Content: View>(_ title: String, icon: String, count: Int, key: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if expanded.contains(key) { expanded.remove(key) } else { expanded.insert(key) }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: icon).frame(width: 18).foregroundStyle(Palette.accent)
                    Text(title).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(count)").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    Image(systemName: expanded.contains(key) ? "chevron.down" : "chevron.right").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }.frame(minHeight: 40).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(groupSummary(key, count: count))
            if expanded.contains(key) { content() }
        }
    }
    private func itemGroup(title: String, items: [HAEntity]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.secondary).padding(.bottom, 3)
            itemRows(items)
        }
    }
    private func groupSummary(_ key: String, count: Int) -> String {
        let countText = count == 1 ? L10n.text("1 item") : L10n.format("%ld itens", count)
        return L10n.format(expanded.contains(key) ? "Expandido, %@" : "Recolhido, %@", countText)
    }
    private func itemRows(_ items: [HAEntity]) -> some View {
        ForEach(items) { entity in
            row(entity).contextMenu { organizationMenu(entity) }
            if entity.id != items.last?.id { Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 43) }
        }
    }
    @ViewBuilder private func organizationMenu(_ entity: HAEntity) -> some View {
        Menu(L10n.text("Classificar como")) {
            ForEach(EntityPurpose.allCases) { purpose in
                Button { store.classify(entity, as: purpose) } label: {
                    if store.purpose(of: entity) == purpose { Label(purpose.title, systemImage: "checkmark") }
                    else { Text(purpose.title) }
                }
            }
            Divider()
            Button(L10n.text("Usar classificação automática")) { store.classify(entity, as: nil) }
                .disabled(store.organization.purposes[entity.id] == nil)
        }
        if store.registryEntries[entity.id]?.hiddenBy != nil || store.registryEntries[entity.id]?.disabledBy != nil {
            Text(L10n.text("Oculto ou desativado no Home Assistant"))
        } else {
            Button(store.organization.hiddenIDs.contains(entity.id) ? L10n.text("Mostrar no app") : L10n.text("Ocultar no app")) {
                store.setHidden(entity, !store.organization.hiddenIDs.contains(entity.id))
            }
        }
        Divider()
        Text(entity.id)
    }
    private var emptyTitle: String {
        if !search.isEmpty { return L10n.text("Nenhum resultado") }
        return store.category == .favorites ? L10n.text("Seus favoritos ficam aqui") : L10n.text("Nenhum item neste cômodo")
    }
    private var emptyDescription: String {
        if !search.isEmpty { return L10n.text("Tente outro nome. A busca inclui consumo e itens técnicos.") }
        return store.category == .favorites ? L10n.text("Toque na estrela dos controles que você usa mais.") : L10n.text("Os itens compatíveis aparecem quando são associados a este cômodo no Home Assistant.")
    }
    private func row(_ entity: HAEntity) -> some View {
        HStack(spacing: 12) {
            if ["climate", "light", "fan", "cover", "camera", "vacuum"].contains(entity.domain) || store.vacuumOwner(of: entity) != nil {
                Button { open(entity) } label: {
                    HStack(spacing: 12) {
                        rowIdentity(entity)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel(L10n.format("Abrir %@", entity.name))
            } else {
                HStack(spacing: 12) { rowIdentity(entity); Spacer(minLength: 4) }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if entity.domain == "scene" {
                Button { store.execute(ServiceCall(entity, "turn_on")) } label: {
                    if store.pendingEntities.contains(entity.id) { ProgressView().controlSize(.small).frame(width: 39) }
                    else { Text(L10n.text("Ativar")).font(.system(size: 11, weight: .medium)) }
                }.buttonStyle(TactileButtonStyle()).disabled(!store.canControl || !entity.available || store.isHidden(entity) || store.pendingEntities.contains(entity.id))
                    .accessibilityLabel(L10n.format("Ativar cena %@", entity.name))
            } else if ["switch", "light"].contains(entity.domain) {
                Toggle(entity.name, isOn: Binding(get: { entity.isOn }, set: { value in store.execute(ServiceCall(entity, value ? "turn_on" : "turn_off")) }))
                    .labelsHidden().toggleStyle(.switch).tint(Palette.accent).controlSize(.small)
                    .disabled(!store.canControl || !entity.available || store.isHidden(entity) || store.pendingEntities.contains(entity.id))
            } else if ["sensor", "binary_sensor"].contains(entity.domain) {
                Text(sensorValue(entity)).font(.system(size: 17, weight: .medium, design: .rounded)).monospacedDigit().lineLimit(1)
                    .foregroundStyle(entity.available ? Palette.text : Palette.secondary)
            } else {
                if let command = ServiceCall.power(entity) {
                    IconButton(icon: "power", label: L10n.format(entity.isOn ? "Desligar %@" : "Ligar %@", entity.name), active: entity.isOn, size: 30) { store.execute(command) }
                        .disabled(!store.canControl || !entity.available || store.isHidden(entity) || store.pendingEntities.contains(entity.id))
                }
            }
            if store.category != .favorites {
                IconButton(icon: store.favoriteIDs.contains(entity.id) ? "star.fill" : "star", label: L10n.format("Favoritar %@", entity.name), active: store.favoriteIDs.contains(entity.id), size: 24) { store.toggleFavorite(entity) }
            }
            if organizing {
                Menu { organizationMenu(entity) } label: { Image(systemName: "ellipsis").font(.system(size: 13)).frame(width: 22, height: 28) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().foregroundStyle(Palette.secondary)
                    .accessibilityLabel(L10n.format("Organizar %@", entity.name))
            }
        }.padding(.vertical, 11)
    }
    private func rowIdentity(_ entity: HAEntity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(entity)).font(.system(size: 23, weight: .light)).foregroundStyle(entity.isOn ? Palette.accent : Palette.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(rowTitle(entity)).font(.system(size: 13, weight: .medium)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Text(subtitle(entity)).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }.frame(minHeight: 44)
    }
    private func rowTitle(_ entity: HAEntity) -> String {
        if entity.domain == "vacuum" { return store.deviceName(for: entity) ?? entity.name }
        if store.purpose(of: entity) == .consumption, ConsumptionMetric.period(entity) != nil { return store.deviceName(for: entity) ?? entity.name }
        return entity.name
    }
    private func open(_ entity: HAEntity) {
        store.openEntity(entity, fromRoom: scope != nil)
    }
    private func subtitle(_ entity: HAEntity) -> String {
        if !entity.available { return displayName(entity.state) }
        if store.purpose(of: entity) == .consumption {
            return [ConsumptionMetric.period(entity) ?? ConsumptionMetric.classify(entity).title, scope == nil ? store.areas[entity.id] : nil].compactMap { $0 }.joined(separator: " · ")
        }
        if store.isHidden(entity) { return L10n.text("Oculto · use o menu para organizar") }
        if entity.domain == "scene" { return L10n.text("Cena do Home Assistant") }
        if scope != nil && !["sensor", "binary_sensor"].contains(entity.domain) { return displayName(entity.state) }
        return store.areas[entity.id] ?? (entity.domain == "sensor" || entity.domain == "binary_sensor" ? "Home Assistant" : displayName(entity.state))
    }
    private func icon(_ entity: HAEntity) -> String {
        switch entity.domain {
        case "camera": return "video"
        case "vacuum": return "robotic.vacuum"
        case "climate": return "air.conditioner.horizontal"
        case "light": return "lightbulb"
        case "switch": return entity.text("device_class") == "outlet" ? "powerplug" : "lightswitch.on"
        case "fan": return "fan"
        case "cover": return "blinds.horizontal.closed"
        case "scene": return "sparkles"
        default:
            switch entity.text("device_class") {
            case "temperature": return "thermometer.medium"
            case "humidity": return "humidity"
            case "window": return "window.casement"
            case "battery": return "battery.75percent"
            case "power", "energy": return "bolt"
            default: return "sensor"
            }
        }
    }
    private func sensorValue(_ entity: HAEntity) -> String {
        guard entity.available else { return "—" }
        if entity.domain == "binary_sensor" {
            switch entity.text("device_class") {
            case "door", "window", "opening", "garage_door": return entity.state == "on" ? L10n.text("Aberta") : L10n.text("Fechada")
            case "motion", "occupancy", "presence": return entity.state == "on" ? L10n.text("Detectado") : L10n.text("Livre")
            case "connectivity": return entity.state == "on" ? "Online" : "Offline"
            default: return displayName(entity.state)
            }
        }
        let value = Double(entity.state).map { displayNumber($0) } ?? entity.state
        return "\(value)\(entity.text("unit_of_measurement").map { " \($0)" } ?? "")"
    }
}
