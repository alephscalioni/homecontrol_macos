import Combine
import HomeCore
import WidgetKit

@available(macOS 14.0, *)
@MainActor
final class HostControlCoordinator {
    private let store: HomeStore
    private let cameras: CameraManager
    private var cameraHeartbeat: Task<Void, Never>?
    private let cache: ControlSharedStore?
    private var observation: AnyCancellable?
    private var heartbeat: Task<Void, Never>?
    private var previous: FavoriteControlSnapshot?

    init(store: HomeStore, cameras: CameraManager) {
        self.store = store
        self.cameras = cameras
        cache = ControlSharedStore.configured()
        ControlIntentBridge.handler = { [weak self] action in
            guard let self else { throw ControlIntentError.openApp }
            switch action {
            case .power(let id, let value):
                try await self.store.performFavoriteControl(id: id, power: value)
            case .activate(let id):
                try await self.store.performFavoriteControl(id: id, power: nil)
            case .temperature(let id, let direction):
                try await self.store.performClimateWidgetControl(id: id, direction: direction)
            case .widgetPower(let id, let value):
                try await self.store.performClimateWidgetControl(id: id, power: value)
            case .refreshCamera(let id):
                try await self.cameras.refresh(id: id)
            case .openCamera(let id):
                try await self.store.waitForControlConnection()
                guard self.store.cameraEntity(id: id) != nil else { throw ControlIntentError.missingWidgetItem }
                self.cameras.openViewer?(id)
            case .homeWidget(let id, let power):
                try await self.store.performHomeWidgetControl(id: id, power: power)
            }
            self.publish()
        }
        cameras.onSnapshot = { [weak self] in self?.reload() }
        cameraHeartbeat = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshSelectedCameras()
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
        observation = store.objectWillChange
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] in self?.publish() }
        publish()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.publish(force: true)
            }
        }
    }

    func stop() {
        observation?.cancel(); heartbeat?.cancel(); cameraHeartbeat?.cancel()
        cameras.stop()
        ControlIntentBridge.handler = nil
        if let previous {
            try? cache?.write(FavoriteControlSnapshot(serverID: previous.serverID, favorites: previous.favorites, connected: false, climates: previous.climates, controls: previous.controls))
            reload()
        }
    }

    private func publish(force: Bool = false) {
        let server = store.controlServerID
        func displayValue(_ entity: HAEntity) -> FavoriteControl {
            var entity = entity
            if store.isDemo { entity.attributes["friendly_name"] = .string(L10n.format("%@ · Demonstração", entity.name)) }
            return FavoriteControl(entity: entity, serverID: server, room: store.areas[entity.id])
        }
        let values = store.entities.filter { store.favoriteIDs.contains($0.id) && !store.isHidden($0) }.map(displayValue)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let climates = store.entities.filter { $0.domain == "climate" && !store.isHidden($0) }.map(displayValue)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let controls = store.widgetEntities.map(displayValue)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let snapshot = FavoriteControlSnapshot(serverID: server, favorites: values, connected: store.canUseSystemControls, climates: climates, controls: controls, registryReady: store.registryLoaded)
        let changed = previous?.serverID != server || previous?.favorites != snapshot.favorites || previous?.climates != snapshot.climates || previous?.controls != snapshot.controls || previous?.connected != snapshot.connected
        guard force || changed else { return }
        do {
            try cache?.write(snapshot)
            previous = snapshot
            if changed { reload() }
        } catch {
            // A control cannot access credentials or silently fall back to another account.
            // Keep the panel usable if shared storage is temporarily unavailable.
        }
    }

    private func refreshSelectedCameras() async {
        guard store.canUseSystemControls else { return }
        let generation = store.cameraConnectionID
        let result: Result<[WidgetInfo], Error> = await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { continuation.resume(returning: $0) }
        }
        guard generation == store.cameraConnectionID, case .success(let configurations) = result else { return }
        var ids = Set<String>()
        for info in configurations {
            if info.kind == "br.com.homecontrol.climateWidget",
               let intent = info.widgetConfigurationIntent(of: SelectClimateWidgetIntent.self), let device = intent.device {
                ids.insert(device.id)
            } else if info.kind == "br.com.homecontrol.homeWidget",
                      let intent = info.widgetConfigurationIntent(of: SelectHomeWidgetIntent.self) {
                ids.formUnion(HomeWidgetSelection.identifiers(intent.items.map(\.id)))
            }
        }
        for id in ids {
            guard !Task.isCancelled, generation == store.cameraConnectionID else { return }
            guard store.cameraEntity(id: id) != nil else { continue }
            if let value = cameras.images[id], Date().timeIntervalSince(value.capturedAt) < 60 { continue }
            _ = try? await cameras.refresh(id: id)
        }
    }

    private func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: "br.com.homecontrol.climateWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "br.com.homecontrol.homeWidget")
        if #available(macOS 26.0, *) { ControlCenter.shared.reloadAllControls() }
    }
}
