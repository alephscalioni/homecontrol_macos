import AppKit
import Combine
import HomeCore

enum DeviceCategory: String, CaseIterable, Identifiable {
    case rooms, climate, lights, switches, covers, fans, scenes, sensors, favorites
    var id: String { rawValue }
    var title: String {
        switch self {
        case .rooms: return L10n.text("Cômodos")
        case .climate: return L10n.text("Ar-condicionado")
        case .lights: return L10n.text("Luzes")
        case .switches: return L10n.text("Interruptores")
        case .covers: return L10n.text("Cortinas")
        case .fans: return L10n.text("Ventilação")
        case .scenes: return L10n.text("Cenas")
        case .sensors: return L10n.text("Sensores")
        case .favorites: return L10n.text("Favoritos")
        }
    }
    var icon: String {
        switch self {
        case .rooms: return "house"
        case .climate: return "air.conditioner.horizontal"
        case .lights: return "lightbulb"
        case .switches: return "lightswitch.on"
        case .covers: return "blinds.horizontal.closed"
        case .fans: return "fan"
        case .scenes: return "sparkles"
        case .sensors: return "sensor"
        case .favorites: return "star"
        }
    }
    func contains(_ entity: HAEntity) -> Bool {
        switch self {
        case .rooms: return true
        case .climate: return entity.domain == "climate"
        case .lights: return entity.domain == "light"
        case .switches: return entity.domain == "switch"
        case .covers: return entity.isSafeCover
        case .fans: return entity.domain == "fan"
        case .scenes: return entity.domain == "scene"
        case .sensors: return ["sensor", "binary_sensor"].contains(entity.domain)
        case .favorites: return true
        }
    }
}

enum ConnectionPhase { case disconnected, connecting, connected, reconnecting, demo }

@MainActor
final class HomeStore: ObservableObject {
    @Published var entities: [HAEntity] = []
    @Published var phase: ConnectionPhase = .disconnected
    @Published var category: DeviceCategory = .rooms
    @Published var selection: [DeviceCategory: String] = [:]
    @Published var showSettings = true
    @Published var isPanelVisible = false
    @Published var errorMessage: String?
    @Published var feedback: String?
    @Published var pendingEntities: Set<String> = []
    @Published var serverAddress = UserDefaults.standard.string(forKey: "serverAddress") ?? ""
    @Published var areas: [String: String] = [:]
    @Published var registryAreas: [HAArea] = []
    @Published var entityAreaIDs: [String: String] = [:]
    @Published var registryLoaded = false
    @Published var registryLoading = false
    @Published var registryRealtime = false
    @Published var roomScope: RoomScope?
    @Published var detailFromRoom = false
    @Published var detailFromFavorites = false
    @Published var favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])
    @Published var metadataNotice: String?
    @Published private(set) var registryEntries: [String: HARegistryEntity] = [:]
    @Published private(set) var registryDevices: [String: HADevice] = [:]
    @Published private(set) var organization = OrganizationPreferences()
    private let client = HomeAssistantClient()
    private var connectionTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var metadataRefreshTask: Task<Void, Never>?
    private var metadataPollTask: Task<Void, Never>?
    private var metadataLoadID = UUID()
    private var connectionGeneration = UUID()
    private var activeToken = ""
    private var retryCount = 0
    var isDemo: Bool { phase == .demo }
    var canControl: Bool { phase == .demo || phase == .connected }
    var isConnecting: Bool { phase == .connecting || phase == .reconnecting }
    var filtered: [HAEntity] {
        entities.filter { entity in
            entity.isSupported && !isHidden(entity) && category.contains(entity) && (category != .favorites || favoriteIDs.contains(entity.id)) &&
            (![DeviceCategory.climate, .lights, .fans, .covers].contains(category) || purpose(of: entity).isEveryday || selection[category] == entity.id)
        }.sorted {
            let lhs = areas[$0.id] ?? "", rhs = areas[$1.id] ?? ""
            return lhs == rhs ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }
    var selected: HAEntity? { filtered.first { $0.id == selection[category] } ?? filtered.first }
    var categoryItems: [HAEntity] { entities.filter { $0.isSupported && category.contains($0) && (category != .favorites || favoriteIDs.contains($0.id)) } }
    var statusLabel: String {
        switch phase {
        case .demo: return L10n.text("Demonstração · dados de exemplo")
        case .connected: return L10n.text("Home Assistant conectado")
        case .connecting: return L10n.text("Conectando ao Home Assistant…")
        case .reconnecting: return L10n.text("Reconectando · dados desatualizados")
        case .disconnected: return L10n.text("Home Assistant desconectado")
        }
    }

    init() {
        client.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .snapshot(let values): self.entities = values.filter(\.isSupported)
            case .changed(let entity):
                if let index = self.entities.firstIndex(where: { $0.id == entity.id }) {
                    if entity.isSupported { self.entities[index] = entity } else { self.entities.remove(at: index) }
                } else if entity.isSupported { self.entities.append(entity) }
            case .removed(let id): self.entities.removeAll { $0.id == id }
            case .registryChanged: self.scheduleMetadataRefresh()
            case .disconnected(let error):
                if self.phase == .connected {
                    self.errorMessage = self.friendly(error)
                    if error as? HAError == .invalidToken { self.phase = .disconnected; self.showSettings = true }
                    else { self.phase = .reconnecting; self.scheduleReconnect() }
                }
            }
        }
    }

    func restore() {
        guard !serverAddress.isEmpty else { return }
        let address = serverAddress
        phase = .connecting; showSettings = false
        connectionTask = Task {
            do {
                let token = try await Task.detached { try TokenVault.read(for: address) }.value
                guard !Task.isCancelled else { return }
                if let token { self.connect(address: address, token: token) }
                else { phase = .disconnected; showSettings = true; errorMessage = L10n.text("Não foi encontrado um token salvo para este Home Assistant. Conecte novamente para salvar o acesso.") }
            } catch {
                guard !Task.isCancelled else { return }
                phase = .disconnected; showSettings = true; errorMessage = error.localizedDescription
            }
        }
    }

    func connectUsingSavedToken(address: String) {
        let normalized: String
        do { normalized = try ServerAddress.normalize(address).absoluteString }
        catch { errorMessage = error.localizedDescription; return }
        let current = connectionGeneration
        Task {
            do {
                let saved = try await Task.detached { try TokenVault.read(for: normalized) }.value
                guard current == connectionGeneration else { return }
                if let saved { connect(address: normalized, token: saved) }
                else { errorMessage = L10n.text("Não há token salvo para este endereço. Cole um token para conectar.") }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func connect(address: String, token input: String, retry: Bool = false) {
        let url: URL
        let token = input.trimmingCharacters(in: .whitespacesAndNewlines)
        do { url = try ServerAddress.normalize(address) }
        catch { errorMessage = error.localizedDescription; return }
        guard !token.isEmpty else { errorMessage = L10n.text("Cole o token de acesso do seu Home Assistant."); return }
        connectionTask?.cancel(); reconnectTask?.cancel()
        connectionGeneration = UUID()
        let current = connectionGeneration
        client.disconnect()
        if !retry {
            favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])
            entities = []; areas = [:]; registryAreas = []; entityAreaIDs = [:]; registryEntries = [:]; registryDevices = [:]
            registryLoaded = false; roomScope = nil; detailFromRoom = false; retryCount = 0
            restoreOrganization(for: url.absoluteString)
        }
        metadataRefreshTask?.cancel(); metadataPollTask?.cancel(); registryRealtime = false
        phase = retry ? .reconnecting : .connecting
        errorMessage = nil; feedback = nil
        connectionTask = Task {
            do {
                try await client.connect(to: url, token: token)
                guard !Task.isCancelled, current == connectionGeneration else { return }
                if !retry {
                    try await Task.detached { try TokenVault.save(token, for: url.absoluteString) }.value
                }
                guard !Task.isCancelled, current == connectionGeneration else { return }
                guard client.isConnected else { throw HAError.disconnected }
                activeToken = token
                serverAddress = url.absoluteString
                UserDefaults.standard.set(serverAddress, forKey: "serverAddress")
                retryCount = 0; phase = .connected; showSettings = false; errorMessage = nil
                do { try await client.subscribeToRegistryChanges(); registryRealtime = true }
                catch { registryRealtime = false }
                guard !Task.isCancelled, current == connectionGeneration else { return }
                await loadAreas(generation: current)
                startMetadataPolling(generation: current)
            } catch {
                guard current == connectionGeneration, !Task.isCancelled else { return }
                errorMessage = friendly(error)
                if retry && error as? HAError != .invalidToken {
                    phase = .reconnecting; scheduleReconnect()
                } else {
                    client.disconnect(); phase = .disconnected; showSettings = true
                }
            }
        }
    }

    private func loadAreas(generation current: UUID) async {
        let loadID = UUID()
        metadataLoadID = loadID
        registryLoading = true
        defer { if current == connectionGeneration && metadataLoadID == loadID { registryLoading = false } }
        do {
            let registry = try await HARegistry.fetch(using: client)
            guard !Task.isCancelled, current == connectionGeneration, metadataLoadID == loadID else { return }
            registryAreas = registry.areas.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            entityAreaIDs = registry.areaIDsByEntity
            areas = registry.entityAreaNames
            registryEntries = Dictionary(registry.entities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            registryDevices = Dictionary(registry.devices.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            registryLoaded = true; metadataNotice = nil
            if case .area(let id) = roomScope, !registryAreas.contains(where: { $0.id == id }) { roomScope = nil }
        } catch {
            guard !Task.isCancelled, current == connectionGeneration, metadataLoadID == loadID else { return }
            metadataNotice = registryLoaded ? L10n.text("Não foi possível atualizar os cômodos. Exibindo a última organização recebida.") : L10n.text("Os cômodos não puderam ser carregados. Ar-condicionado e Favoritos continuam disponíveis nas abas acima.")
        }
    }

    func refreshAreas() {
        guard phase == .connected else { return }
        metadataRefreshTask?.cancel()
        let current = connectionGeneration
        metadataRefreshTask = Task { await loadAreas(generation: current) }
    }
    private func scheduleMetadataRefresh() {
        guard phase == .connected else { return }
        metadataRefreshTask?.cancel()
        let current = connectionGeneration
        metadataRefreshTask = Task {
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled, current == connectionGeneration else { return }
            await loadAreas(generation: current)
        }
    }
    private func startMetadataPolling(generation current: UUID) {
        metadataPollTask?.cancel()
        metadataPollTask = Task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                guard !Task.isCancelled, current == connectionGeneration, phase == .connected else { return }
                if !registryLoading { await loadAreas(generation: current) }
            }
        }
    }
    func items(in scope: RoomScope) -> [HAEntity] {
        entities.filter { entity in
            switch scope {
            case .all: return true
            case .area(let id): return entityAreaIDs[entity.id] == id
            case .general: return entityAreaIDs[entity.id] == nil && EntityOrganizer.isGeneral(entity, entry: registryEntries[entity.id])
            case .unassigned: return entityAreaIDs[entity.id] == nil && !EntityOrganizer.isGeneral(entity, entry: registryEntries[entity.id])
            }
        }
    }
    func roomName(for scope: RoomScope) -> String {
        switch scope {
        case .all: return L10n.text("Toda a casa")
        case .general: return L10n.text("Geral da casa")
        case .unassigned: return L10n.text("Sem cômodo")
        case .area(let id): return registryAreas.first { $0.id == id }?.name ?? L10n.text("Cômodo")
        }
    }
    var topCategory: DeviceCategory { detailFromFavorites || category == .favorites ? .favorites : (category == .climate && !detailFromRoom ? .climate : .rooms) }
    func showCategory(_ value: DeviceCategory) { detailFromRoom = false; detailFromFavorites = false; category = value }
    func openEntity(_ entity: HAEntity, fromRoom: Bool) {
        guard let next = DeviceCategory.allCases.first(where: { $0 != .rooms && $0 != .favorites && $0.contains(entity) }) else { return }
        detailFromFavorites = category == .favorites; detailFromRoom = fromRoom; selection[next] = entity.id; category = next
    }
    func returnToRoom() { category = detailFromFavorites ? .favorites : .rooms; detailFromRoom = false; detailFromFavorites = false }

    func purpose(of entity: HAEntity) -> EntityPurpose {
        EntityOrganizer.purpose(for: entity, entry: registryEntries[entity.id], override: organization.purposes[entity.id])
    }
    func isHidden(_ entity: HAEntity) -> Bool { organization.isHidden(entity, entry: registryEntries[entity.id]) }
    func everydayItems(in scope: RoomScope) -> [HAEntity] { items(in: scope).filter { !isHidden($0) && purpose(of: $0).isEveryday } }
    func deviceName(for entity: HAEntity) -> String? { registryEntries[entity.id]?.deviceID.flatMap { registryDevices[$0]?.name } }
    func classify(_ entity: HAEntity, as purpose: EntityPurpose?) {
        organization.purposes[entity.id] = purpose
        saveOrganization()
    }
    func setHidden(_ entity: HAEntity, _ hidden: Bool) {
        if hidden { organization.hiddenIDs.insert(entity.id) } else { organization.hiddenIDs.remove(entity.id) }
        saveOrganization()
    }
    private var organizationKey: String { "organization." + (isDemo ? "demo" : serverAddress) }
    private func restoreOrganization(for address: String) {
        organization = UserDefaults.standard.data(forKey: "organization." + address).flatMap { try? JSONDecoder().decode(OrganizationPreferences.self, from: $0) } ?? OrganizationPreferences()
    }
    private func saveOrganization() {
        if let data = try? JSONEncoder().encode(organization) { UserDefaults.standard.set(data, forKey: organizationKey) }
    }

    private func scheduleReconnect() {
        guard !activeToken.isEmpty, !serverAddress.isEmpty else { phase = .disconnected; showSettings = true; return }
        retryCount += 1
        let delay = min(30.0, pow(2, Double(min(retryCount, 5)))) + Double.random(in: 0...0.7)
        reconnectTask?.cancel()
        reconnectTask = Task {
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard !Task.isCancelled else { return }
            connect(address: serverAddress, token: activeToken, retry: true)
        }
    }
    func retryNow() {
        guard !activeToken.isEmpty else { showSettings = true; return }
        connect(address: serverAddress, token: activeToken, retry: true)
    }
    func wake() { if phase == .connected || phase == .reconnecting { retryNow() } }

    func useDemo() {
        stopConnection()
        serverAddress = ""
        favoriteIDs = Set(UserDefaults.standard.stringArray(forKey: "favorites.demo") ?? [])
        entities = DemoHome.entities
        areas = DemoHome.areas
        let registry = DemoHome.registry
        registryAreas = registry.areas; entityAreaIDs = registry.areaIDsByEntity
        registryEntries = Dictionary(uniqueKeysWithValues: registry.entities.map { ($0.id, $0) })
        registryDevices = Dictionary(uniqueKeysWithValues: registry.devices.map { ($0.id, $0) })
        restoreOrganization(for: "demo")
        registryLoaded = true; registryLoading = false; registryRealtime = false
        roomScope = nil; detailFromRoom = false
        phase = .demo; showSettings = false; category = .rooms
        errorMessage = nil; metadataNotice = nil; feedback = nil
    }
    func stopConnection() {
        connectionGeneration = UUID()
        connectionTask?.cancel(); reconnectTask?.cancel(); client.disconnect()
        metadataRefreshTask?.cancel(); metadataPollTask?.cancel()
        registryLoading = false; registryRealtime = false
        activeToken = ""; phase = .disconnected; pendingEntities = []
    }
    func forgetConnection() {
        let account = serverAddress
        stopConnection()
        Task {
            do {
                try await Task.detached { try TokenVault.delete(for: account) }.value
                UserDefaults.standard.removeObject(forKey: "serverAddress")
                serverAddress = ""; entities = []; areas = [:]; showSettings = true; errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        }
    }
    func toggleFavorite(_ entity: HAEntity) {
        if favoriteIDs.contains(entity.id) { favoriteIDs.remove(entity.id) } else { favoriteIDs.insert(entity.id) }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: isDemo ? "favorites.demo" : "favorites")
    }
    var controlServerID: String { FavoriteControl.serverID(for: isDemo ? "homecontrol-demo" : serverAddress) }
    var canUseSystemControls: Bool { canControl && registryLoaded }

    var widgetEntities: [HAEntity] {
        guard registryLoaded else { return [] }
        return entities.filter {
            !isHidden($0) && (purpose(of: $0).isEveryday || $0.domain == "scene" || favoriteIDs.contains($0.id))
                && HomeWidgetSelection.supports(FavoriteControl(entity: $0, serverID: controlServerID))
        }
    }

    func waitForControlConnection() async throws {
        let deadline = Date().addingTimeInterval(15)
        while (isConnecting || (canControl && !registryLoaded)) && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        try Task.checkCancellation()
        guard canUseSystemControls else { throw ControlIntentError.unavailable }
    }

    func controlEntity(for controlID: String) throws -> HAEntity {
        guard let entity = entities.first(where: {
            favoriteIDs.contains($0.id) && !isHidden($0)
                && FavoriteControl(entity: $0, serverID: controlServerID).id == controlID
        }) else { throw ControlIntentError.missingFavorite }
        return entity
    }

    func performFavoriteControl(id: String, power: Bool?) async throws {
        try await waitForControlConnection()
        let entity = try controlEntity(for: id)
        guard entity.available, !pendingEntities.contains(entity.id) else { throw ControlIntentError.unavailable }
        let kind = FavoriteControl(entity: entity, serverID: controlServerID).kind
        let command: ServiceCall
        if let power {
            guard kind == .toggle else { throw ControlIntentError.unsupported }
            if entity.isOn == power { return }
            guard let value = ServiceCall.setPower(entity, isOn: power) else { throw ControlIntentError.unsupported }
            command = value
        } else {
            guard kind == .scene else { throw ControlIntentError.unsupported }
            command = ServiceCall(entity, "turn_on")
        }
        try await performSystemControl(command, entity: entity, refresh: power != nil)
    }

    func performClimateWidgetControl(id: String, direction: Int? = nil, power: Bool? = nil) async throws {
        try await waitForControlConnection()
        guard let entity = entities.first(where: {
            $0.domain == "climate" && !isHidden($0)
                && FavoriteControl(entity: $0, serverID: controlServerID).id == id
        }) else { throw ControlIntentError.missingFavorite }
        guard entity.available, !pendingEntities.contains(entity.id) else { throw ControlIntentError.unavailable }
        let command: ServiceCall
        if let direction {
            guard let value = ServiceCall.adjustTemperature(entity, direction: direction) else { throw ControlIntentError.unsupported }
            command = value
        } else if let power {
            if entity.isOn == power { return }
            guard let value = ServiceCall.setPower(entity, isOn: power) else { throw ControlIntentError.unsupported }
            command = value
        } else { throw ControlIntentError.unsupported }
        try await performSystemControl(command, entity: entity, refresh: true)
    }

    func performHomeWidgetControl(id: String, power: Bool? = nil) async throws {
        try await waitForControlConnection()
        guard let entity = widgetEntities.first(where: {
            FavoriteControl(entity: $0, serverID: controlServerID).id == id
        }) else { throw ControlIntentError.missingWidgetItem }
        guard entity.available, !pendingEntities.contains(entity.id) else { throw ControlIntentError.unavailable }
        let value = FavoriteControl(entity: entity, serverID: controlServerID)
        let command: ServiceCall
        if let power {
            guard value.kind == .toggle else { throw ControlIntentError.unsupported }
            if entity.isOn == power { return }
            guard let call = ServiceCall.setPower(entity, isOn: power) else { throw ControlIntentError.unsupported }
            command = call
        } else {
            guard value.kind == .scene else { throw ControlIntentError.unsupported }
            command = ServiceCall(entity, "turn_on")
        }
        try await performSystemControl(command, entity: entity, refresh: power != nil)
    }

    private func performSystemControl(_ command: ServiceCall, entity: HAEntity, refresh: Bool) async throws {
        let current = connectionGeneration
        pendingEntities.insert(entity.id)
        defer { if current == connectionGeneration { pendingEntities.remove(entity.id) } }
        if isDemo {
            if let index = entities.firstIndex(where: { $0.id == entity.id }) { DemoHome.apply(command, to: &entities[index]) }
        } else {
            try await client.call(command)
            guard current == connectionGeneration else { throw HAError.disconnected }
            guard refresh else { return }
            // Query the acknowledged server state before WidgetKit asks for its value again.
            let result = try await client.request(["type": .string("get_states")])
            guard current == connectionGeneration else { throw HAError.disconnected }
            let refreshed = try JSONDecoder().decode([HAEntity].self, from: JSONEncoder().encode(result))
            if let updated = refreshed.first(where: { $0.id == entity.id }),
               let index = entities.firstIndex(where: { $0.id == entity.id }),
               updated.timestamp == nil || entities[index].timestamp == nil || updated.timestamp! >= entities[index].timestamp! {
                entities[index] = updated
            }
        }
    }
    func execute(_ command: ServiceCall?) {
        guard let command, canControl,
              let entity = entities.first(where: { $0.id == command.entityID }), entity.available,
              !pendingEntities.contains(command.entityID) else { return }
        let current = connectionGeneration
        let demo = isDemo
        pendingEntities.insert(command.entityID)
        errorMessage = nil
        Task {
            do {
                if demo {
                    try await Task.sleep(for: .milliseconds(180))
                    guard current == connectionGeneration, isDemo else { return }
                    if let index = entities.firstIndex(where: { $0.id == command.entityID }) {
                        DemoHome.apply(command, to: &entities[index])
                    }
                } else {
                    try await client.call(command)
                }
                guard current == connectionGeneration else { return }
                pendingEntities.remove(command.entityID)
                flash(demo ? L10n.text("Alterado na demonstração") : L10n.text("Comando aceito pelo Home Assistant"))
            } catch {
                guard current == connectionGeneration else { return }
                pendingEntities.remove(command.entityID)
                errorMessage = friendly(error)
            }
        }
    }
    func flash(_ message: String) {
        feedbackTask?.cancel(); feedback = message
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { feedback = nil }
        }
    }
    func friendly(_ error: Error) -> String {
        if let error = error as? URLError {
            switch error.code {
            case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return L10n.text("Não foi possível alcançar o Home Assistant. Confira o endereço e a conexão com a rede da sua casa.")
            case .serverCertificateUntrusted, .serverCertificateHasBadDate, .secureConnectionFailed:
                return L10n.text("A conexão segura foi recusada. Confira o certificado e o endereço do Home Assistant.")
            default: break
            }
        }
        return error.localizedDescription
    }
}
