import XCTest
@testable import HomeCore

final class ConnectionTests: XCTestCase {
    @MainActor func testConcurrentRequestsAndRegistryReconciliationKeepIncreasingWireIDs() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        try await client.connect(to: address(), token: "test-registry")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<60 {
                group.addTask(priority: index.isMultiple(of: 2) ? .high : .low) {
                    if index.isMultiple(of: 3) { _ = try await HARegistry.fetch(using: client) }
                    else { _ = try await client.request(["type": .string("ping")]) }
                }
            }
            try await group.waitForAll()
        }
        let registry = try await HARegistry.fetch(using: client)
        XCTAssertEqual(registry.areaIDsByEntity["climate.test"], "office")
    }
    @MainActor func testRegistryEventsAndInheritedRoomAreAvailableWithoutRestart() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        var updates = 0
        client.onEvent = { if case .registryChanged = $0 { updates += 1 } }
        try await client.connect(to: address(), token: "test-registry")
        try await client.subscribeToRegistryChanges()
        let registry = try await HARegistry.fetch(using: client)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(updates, 3)
        XCTAssertEqual(registry.areaIDsByEntity["climate.test"], "office")
        XCTAssertEqual(registry.entityAreaNames["climate.test"], "Escritório")
        try await client.subscribeToRegistryChanges()
        XCTAssertEqual(updates, 3, "A second call must not create duplicate event subscriptions")
    }
    private func address() throws -> URL {
        guard let value = ProcessInfo.processInfo.environment["HA_TEST_SERVER"] else {
            throw XCTSkip("Run scripts/test-integration.sh to start the local simulated Home Assistant.")
        }
        return try ServerAddress.normalize(value)
    }
    @MainActor func testAuthenticationSnapshotAndTargetedServiceCall() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        var states: [HAEntity] = []
        client.onEvent = { if case .snapshot(let entities) = $0 { states = entities } }
        try await client.connect(to: address(), token: "test-valid")
        let entity = try XCTUnwrap(states.first)
        XCTAssertEqual(entity.id, "climate.test")
        try await client.call(try XCTUnwrap(ServiceCall.temperature(entity, value: 22)))
    }
    @MainActor func testInvalidTokenKeepsAuthenticationError() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        do { try await client.connect(to: address(), token: "test-invalid"); XCTFail("Invalid token was accepted") }
        catch { XCTAssertEqual(error as? HAError, .invalidToken) }
    }
    @MainActor func testSubscriptionFailureCannotLookLikeSuccessfulSync() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        var synchronized = false
        client.onEvent = { if case .snapshot = $0 { synchronized = true } }
        do { try await client.connect(to: address(), token: "test-subscribe-error"); XCTFail("Subscription rejection was ignored") }
        catch { XCTAssertFalse(synchronized) }
    }
    @MainActor func testSnapshotReconciliationAndRemovalTombstones() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        var snapshot: [HAEntity] = [], changes: [HAEntity] = [], removals: [String] = []
        client.onEvent = {
            switch $0 {
            case .snapshot(let values): snapshot = values
            case .changed(let entity): changes.append(entity)
            case .removed(let id): removals.append(id)
            default: break
            }
        }
        try await client.connect(to: address(), token: "test-stale")
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertEqual(snapshot.first?.number("temperature"), 21)
        XCTAssertEqual(changes.map { $0.number("temperature") }, [23])
        XCTAssertEqual(removals, ["climate.test"])
    }
    @MainActor func testRejectedServiceIsNotReportedAsSuccess() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        try await client.connect(to: address(), token: "test-service-error")
        do { try await client.call(ServiceCall(HAEntity("light.test", state: "off", attributes: [:]), "turn_on")); XCTFail("Service rejection was ignored") }
        catch { XCTAssertEqual(error as? HAError, .server("Ação não permitida")) }
    }
    @MainActor func testCommandTimeoutDoesNotHang() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        try await client.connect(to: address(), token: "test-timeout")
        client.commandTimeout = 0.1
        do { try await client.call(ServiceCall(HAEntity("light.test", state: "off", attributes: [:]), "turn_on")); XCTFail("Expected a timeout") }
        catch { XCTAssertEqual(error as? HAError, .timeout) }
        _ = try await client.request(["type": .string("ping")])
    }
    @MainActor func testCancelledRequestCompletesExactlyOnce() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        try await client.connect(to: address(), token: "test-valid")
        let task = Task { try await client.request(["type": .string("never")]) }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        _ = try await client.request(["type": .string("ping")])
    }
    @MainActor func testServerDisconnectFailsPendingCommand() async throws {
        let client = HomeAssistantClient()
        defer { client.disconnect() }
        try await client.connect(to: address(), token: "test-disconnect")
        do { try await client.call(ServiceCall(HAEntity("light.test", state: "off", attributes: [:]), "turn_on")); XCTFail("Expected disconnect") }
        catch { XCTAssertNotEqual(error as? HAError, .timeout) }
    }
}
