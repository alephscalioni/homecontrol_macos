import Foundation

@MainActor
public final class HomeAssistantClient {
    public enum Event {
        case snapshot([HAEntity]), changed(HAEntity), removed(String), registryChanged, disconnected(Error)
    }
    public var onEvent: ((Event) -> Void)?
    public private(set) var isConnected = false
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var receiver: Task<Void, Never>?
    private var heartbeat: Task<Void, Never>?
    private var generation = UUID()
    private var nextID = 0
    private var authentication: CheckedContinuation<Void, Error>?
    private var authTimeout: Task<Void, Never>?
    private struct Pending {
        let continuation: CheckedContinuation<JSONValue, Error>
        let timeout: Task<Void, Never>
    }
    private var pending: [Int: Pending] = [:]
    private struct Outgoing { let id: Int; let message: String }
    private var outgoing: [Outgoing] = []
    private var sender: Task<Void, Never>?
    private var token = ""
    private var buffering = false
    private struct Change { let id: String; let entity: HAEntity?; let date: Date? }
    private var buffer: [Change] = []
    private var versions: [String: Date] = [:]
    private var registrySubscriptions: Set<String> = []
    public var commandTimeout: TimeInterval = 12

    public init() {}

    public func connect(to base: URL, token: String) async throws {
        disconnect()
        let current = generation
        self.token = token
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        self.session = session
        let task = session.webSocketTask(with: ServerAddress.websocket(base))
        socket = task
        task.resume()
        receiver = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    guard let self, self.generation == current else { return }
                    let data: Data
                    switch message {
                    case .data(let value): data = value
                    case .string(let value): data = Data(value.utf8)
                    @unknown default: throw HAError.malformed
                    }
                    let value = try JSONDecoder().decode(JSONValue.self, from: data)
                    try await self.receive(value, generation: current)
                } catch {
                    guard let self, self.generation == current else { return }
                    self.fail(error)
                    return
                }
            }
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                authentication = continuation
                authTimeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(12))
                    guard !Task.isCancelled, let self, self.generation == current else { return }
                    self.fail(HAError.timeout)
                }
            }
            try Task.checkCancellation()
            guard generation == current else { throw HAError.disconnected }
            buffering = true
            _ = try await request(["type": .string("subscribe_events"), "event_type": .string("state_changed")])
            let result = try await request(["type": .string("get_states")])
            guard case .array = result else { throw HAError.malformed }
            let entities = try result.array.map { try decodeEntity($0) }
            var states = Dictionary(entities.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            versions = Dictionary(entities.compactMap { entity in entity.timestamp.map { (entity.id, $0) } }, uniquingKeysWith: { _, last in last })
            for change in buffer {
                guard shouldApply(change) else { continue }
                states[change.id] = change.entity
            }
            buffer.removeAll()
            buffering = false
            isConnected = true
            onEvent?(.snapshot(Array(states.values)))
            heartbeat = Task { [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(25))
                        guard let self, self.generation == current else { return }
                        _ = try await self.request(["type": .string("ping")])
                    } catch {
                        guard !Task.isCancelled, let self, self.generation == current else { return }
                        self.fail(error)
                        return
                    }
                }
            }
        } catch {
            if generation == current { disconnect() }
            throw error
        }
    }

    public func request(_ payload: [String: JSONValue]) async throws -> JSONValue {
        try Task.checkCancellation()
        guard socket != nil else { throw HAError.disconnected }
        nextID += 1
        let id = nextID
        var payload = payload
        payload["id"] = .number(Double(id))
        let encoded = try JSONEncoder().encode(JSONValue.object(payload))
        let message = String(decoding: encoded, as: UTF8.self)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timeout = Task { [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(for: .seconds(self.commandTimeout))
                    if !Task.isCancelled { self.finish(id, result: .failure(HAError.timeout)) }
                }
                pending[id] = Pending(continuation: continuation, timeout: timeout)
                if Task.isCancelled {
                    finish(id, result: .failure(CancellationError()))
                    return
                }
                enqueue(Outgoing(id: id, message: message))
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(id, result: .failure(CancellationError())) }
        }
    }

    /// Home Assistant requires increasing message IDs on the wire, even for concurrent callers.
    private func enqueue(_ item: Outgoing) {
        outgoing.append(item)
        guard sender == nil, let socket else { return }
        let current = generation
        sender = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, generation == current, !outgoing.isEmpty {
                let next = outgoing.removeFirst()
                guard pending[next.id] != nil else { continue }
                do { try await socket.send(.string(next.message)) }
                catch {
                    guard generation == current else { return }
                    finish(next.id, result: .failure(error))
                }
            }
            if generation == current { sender = nil }
        }
    }

    public func call(_ command: ServiceCall) async throws { _ = try await request(command.payload) }

    public func subscribeToRegistryChanges() async throws {
        let current = generation
        for type in ["area_registry_updated", "device_registry_updated", "entity_registry_updated"] where !registrySubscriptions.contains(type) {
            try Task.checkCancellation()
            guard generation == current, isConnected else { throw HAError.disconnected }
            _ = try await request(["type": .string("subscribe_events"), "event_type": .string(type)])
            try Task.checkCancellation()
            guard generation == current, isConnected else { throw HAError.disconnected }
            registrySubscriptions.insert(type)
        }
    }

    public func disconnect() {
        isConnected = false
        generation = UUID()
        receiver?.cancel(); receiver = nil
        sender?.cancel(); sender = nil; outgoing.removeAll()
        heartbeat?.cancel(); heartbeat = nil
        authTimeout?.cancel(); authTimeout = nil
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
        session?.invalidateAndCancel(); session = nil
        authentication?.resume(throwing: HAError.disconnected); authentication = nil
        for id in Array(pending.keys) { finish(id, result: .failure(HAError.disconnected)) }
        token = ""; buffer.removeAll(); buffering = false; versions.removeAll()
        registrySubscriptions.removeAll()
    }

    private func receive(_ value: JSONValue, generation current: UUID) async throws {
        switch value["type"].string {
        case "auth_required":
            guard let socket, authentication != nil else { return }
            let data = try JSONEncoder().encode(JSONValue.object(["type": .string("auth"), "access_token": .string(token)]))
            try await socket.send(.string(String(decoding: data, as: UTF8.self)))
            guard generation == current else { throw HAError.disconnected }
        case "auth_ok":
            token = ""
            authTimeout?.cancel(); authTimeout = nil
            authentication?.resume(); authentication = nil
        case "auth_invalid": throw HAError.invalidToken
        case "pong":
            if let id = value["id"].number { finish(Int(id), result: .success(.null)) }
        case "result":
            guard let rawID = value["id"].number else { return }
            if value["success"].bool == true { finish(Int(rawID), result: .success(value["result"])) }
            else { finish(Int(rawID), result: .failure(HAError.server(value["error"]["message"].string ?? "O Home Assistant recusou a ação."))) }
        case "event":
            let event = value["event"]
            if let type = event["event_type"].string, ["area_registry_updated", "device_registry_updated", "entity_registry_updated"].contains(type) {
                onEvent?(.registryChanged)
                return
            }
            guard event["event_type"].string == "state_changed", let id = event["data"]["entity_id"].string else { return }
            let raw = event["data"]["new_state"]
            let entity = raw == .null ? nil : try decodeEntity(raw)
            let change = Change(id: id, entity: entity, date: entity?.timestamp ?? HAEntity.date(event["time_fired"].string))
            if buffering { buffer.append(change) }
            else if shouldApply(change) {
                if let entity { onEvent?(.changed(entity)) } else { onEvent?(.removed(id)) }
            }
        default: break
        }
    }
    private func shouldApply(_ change: Change) -> Bool {
        if let date = change.date {
            if let previous = versions[change.id], date < previous { return false }
            versions[change.id] = date
        }
        return true
    }
    private func decodeEntity(_ value: JSONValue) throws -> HAEntity {
        try JSONDecoder().decode(HAEntity.self, from: JSONEncoder().encode(value))
    }
    private func finish(_ id: Int, result: Result<JSONValue, Error>) {
        guard let entry = pending.removeValue(forKey: id) else { return }
        entry.timeout.cancel()
        entry.continuation.resume(with: result)
    }
    private func fail(_ error: Error) {
        authentication?.resume(throwing: error); authentication = nil
        for id in Array(pending.keys) { finish(id, result: .failure(error)) }
        disconnect()
        onEvent?(.disconnected(error))
    }
}
