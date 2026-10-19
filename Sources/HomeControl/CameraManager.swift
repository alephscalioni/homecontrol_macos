import AppKit
import Combine
import HomeCore
import ImageIO

@MainActor
final class CameraManager: ObservableObject {
    let store: HomeStore
    @Published private(set) var images: [String: CameraSnapshot] = [:]
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var pending: Set<String> = []
    var openViewer: ((String) -> Void)?
    var onSnapshot: (() -> Void)?
    private let cache = CameraSnapshotStore.configured()
    private var requests: [String: Task<CameraSnapshot, Error>] = [:]
    private var context = ""
    private var observation: AnyCancellable?
    private var connectionObservation: AnyCancellable?

    init(store: HomeStore) {
        self.store = store
        context = store.cameraConnectionID
        try? cache?.retain(only: [])
        connectionObservation = store.cameraConnectionWillChange.sink { [weak self] in self?.invalidate() }
        observation = store.objectWillChange.throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] in self?.reconcile() }
    }

    func reconcile() {
        let valid = Set(store.widgetEntities.filter { $0.domain == "camera" }.map { FavoriteControl(entity: $0, serverID: store.controlServerID).id })
        if context != store.cameraConnectionID {
            context = store.cameraConnectionID
            invalidate()
        } else {
            let removed = Set(images.keys).subtracting(valid)
            for id in removed { images[id] = nil; errors[id] = nil; requests[id]?.cancel(); requests[id] = nil }
            try? cache?.retain(only: valid)
            if !removed.isEmpty { onSnapshot?() }
        }
    }

    private func invalidate() {
        for request in requests.values { request.cancel() }
        requests = [:]; pending = []; images = [:]; errors = [:]
        try? cache?.retain(only: [])
        onSnapshot?()
    }

    @discardableResult func refresh(id: String) async throws -> CameraSnapshot {
        try await store.waitForControlConnection()
        reconcile()
        guard let entity = store.cameraEntity(id: id), entity.available, entity.state != "off" else { throw CameraMediaError.invalidRequest }
        if let request = requests[id] { return try await request.value }
        let generation = context
        let demo = store.isDemo
        let request = demo ? nil : try store.cameraRequest(id: id)
        pending.insert(id); errors[id] = nil
        let task = Task<CameraSnapshot, Error> {
            let data: Data
            if let request { data = try await CameraMedia.image(for: request) }
            else { data = Self.demoFrame() }
            try Task.checkCancellation()
            let jpeg = try await Task.detached(priority: .utility) { try Self.thumbnail(data) }.value
            try Task.checkCancellation()
            return CameraSnapshot(data: jpeg)
        }
        requests[id] = task
        do {
            let value = try await task.value
            guard generation == store.cameraConnectionID, store.cameraEntity(id: id) != nil else { throw CancellationError() }
            images[id] = value
            try cache?.write(value, id: id)
            requests[id] = nil; pending.remove(id)
            onSnapshot?()
            return value
        } catch {
            if generation == store.cameraConnectionID {
                requests[id] = nil; pending.remove(id)
                if !(error is CancellationError) { errors[id] = L10n.text("Não foi possível atualizar a imagem. Tente novamente.") }
                onSnapshot?()
            }
            // Network errors may include the private URL. Present only our own messages.
            if error is CancellationError { throw error }
            throw CameraMediaError.unavailable
        }
    }

    func stop() {
        observation?.cancel(); connectionObservation?.cancel()
        for request in requests.values { request.cancel() }
        requests = [:]; images = [:]; pending = []
        try? cache?.retain(only: [])
    }

    nonisolated static func thumbnail(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0, width <= 16384, height <= 16384,
              Double(width) * Double(height) <= 40_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 720,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw CameraMediaError.invalidImage }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil) else { throw CameraMediaError.invalidImage }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= CameraSnapshotStore.maximumBytes else { throw CameraMediaError.tooLarge }
        return output as Data
    }

    /// A test signal, never a real household image. The moving marker exercises frames.
    static func demoFrame(at date: Date = Date()) -> Data {
        let image = NSImage(size: NSSize(width: 720, height: 405))
        image.lockFocus()
        let colors: [NSColor] = [.init(srgbRed: 0.19, green: 0.29, blue: 0.29, alpha: 1), .init(srgbRed: 0.31, green: 0.40, blue: 0.37, alpha: 1), .init(srgbRed: 0.49, green: 0.52, blue: 0.43, alpha: 1), .init(srgbRed: 0.73, green: 0.69, blue: 0.55, alpha: 1)]
        for (i, color) in colors.enumerated() { color.setFill(); NSRect(x: i * 180, y: 0, width: 180, height: 405).fill() }
        NSColor.black.withAlphaComponent(0.4).setFill(); NSRect(x: 0, y: 0, width: 720, height: 78).fill()
        let text = L10n.text("Câmera · sinal de demonstração")
        (text as NSString).draw(at: NSPoint(x: 24, y: 28), withAttributes: [.font: NSFont.systemFont(ofSize: 22, weight: .medium), .foregroundColor: NSColor.white])
        NSColor.white.withAlphaComponent(0.9).setFill()
        let x = 50 + (date.timeIntervalSince1970.truncatingRemainder(dividingBy: 8) / 8) * 600
        NSBezierPath(ovalIn: NSRect(x: x, y: 190, width: 20, height: 20)).fill()
        image.unlockFocus()
        return image.tiffRepresentation ?? Data()
    }
}

@MainActor
final class CameraLiveSession: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var lastFrame: Date?
    @Published private(set) var error: String?
    @Published private(set) var running = false
    private var task: Task<Void, Never>?
    private var transmission: CameraTransmission?
    private var observation: AnyCancellable?
    private var connectionObservation: AnyCancellable?
    private var context = ""
    private let cameras: CameraManager
    let id: String
    init(cameras: CameraManager, id: String) {
        self.cameras = cameras; self.id = id
        connectionObservation = cameras.store.cameraConnectionWillChange.sink { [weak self] in self?.stop(clear: true) }
        observation = cameras.store.objectWillChange.throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true).sink { [weak self] in
            guard let self else { return }
            if self.context != self.cameras.store.cameraConnectionID || self.cameras.store.cameraEntity(id: self.id) == nil {
                self.stop(clear: true)
            }
        }
    }
    func start() {
        stop(clear: false); error = nil; running = true
        context = cameras.store.cameraConnectionID
        let generation = context
        task = Task {
            do {
                try Task.checkCancellation()
                guard cameras.store.cameraEntity(id: id) != nil else { throw CameraMediaError.invalidRequest }
                if cameras.store.isDemo {
                    while !Task.isCancelled {
                        image = NSImage(data: CameraManager.demoFrame()); lastFrame = Date()
                        try await Task.sleep(for: .milliseconds(200))
                    }
                } else {
                    let request = try cameras.store.cameraRequest(id: id, streaming: true)
                    var decodedAt = Date.distantPast
                    let stream = CameraMedia.stream(for: request)
                    transmission = stream
                    defer { stream.cancel() }
                    for try await data in stream.frames {
                        try Task.checkCancellation()
                        guard generation == cameras.store.cameraConnectionID, cameras.store.cameraEntity(id: id) != nil else { throw CancellationError() }
                        guard Date().timeIntervalSince(decodedAt) >= 0.1 else { continue }
                        decodedAt = Date()
                        let jpeg = try await Task.detached(priority: .userInitiated) { try CameraManager.thumbnail(data) }.value
                        try Task.checkCancellation()
                        guard generation == cameras.store.cameraConnectionID, cameras.store.cameraEntity(id: id) != nil else { throw CancellationError() }
                        guard let frame = NSImage(data: jpeg) else { throw CameraMediaError.invalidImage }
                        image = frame; lastFrame = Date()
                    }
                }
            } catch {
                guard !Task.isCancelled, generation == cameras.store.cameraConnectionID else { return }
                self.error = L10n.text("A transmissão não está disponível. Tente novamente ou confira a câmera no Home Assistant.")
                running = false
            }
        }
    }
    func stop(clear: Bool) {
        transmission?.cancel(); transmission = nil
        task?.cancel(); task = nil; running = false
        if clear { image = nil; lastFrame = nil; error = L10n.text("A câmera foi desconectada. Conecte o HomeControl e tente novamente.") }
    }
}
