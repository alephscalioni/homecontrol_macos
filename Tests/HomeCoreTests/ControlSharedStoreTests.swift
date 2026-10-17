import Foundation
import XCTest
@testable import HomeCore

final class ControlSharedStoreTests: XCTestCase {
    func testInitialSnapshotDoesNotPublishUnvalidatedItemsBeforeRegistryIsReady() throws {
        let light = FavoriteControl(entity: HAEntity("light.hidden", state: "on", attributes: ["friendly_name": .string("Registry-hidden light")]), serverID: "fixture")
        let climate = FavoriteControl(entity: HAEntity("climate.pending", state: "off", attributes: ["supported_features": .number(385)]), serverID: "fixture")
        let pending = FavoriteControlSnapshot(serverID: "fixture", favorites: [light], connected: true,
                                              climates: [climate], controls: [light, climate], registryReady: false)
        XCTAssertFalse(pending.connected)
        XCTAssertTrue(pending.favorites.isEmpty)
        XCTAssertEqual(pending.climates, [])
        XCTAssertTrue(HomeWidgetSelection.options(in: pending).isEmpty)
        let payload = String(decoding: try JSONEncoder().encode(pending), as: UTF8.self)
        XCTAssertFalse(payload.contains("light.hidden"))
        XCTAssertFalse(payload.contains("climate.pending"))
        // After registry validation, publish only the items confirmed as visible.
        let ready = FavoriteControlSnapshot(serverID: "fixture", favorites: [], connected: true,
                                            climates: [climate], controls: [climate], registryReady: true)
        XCTAssertTrue(ready.connected)
        XCTAssertEqual(HomeWidgetSelection.options(in: ready), [climate])
    }

    func testSharedSnapshotRoundTripAndReplacement() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ControlSharedStore(directory: directory)
        let value = FavoriteControl(entity: HAEntity("light.sample", state: "on", attributes: ["friendly_name": .string("Sample light")]), serverID: "test")
        let snapshot = FavoriteControlSnapshot(serverID: "test", favorites: [value], connected: true)
        try store.write(snapshot)
        XCTAssertEqual(try store.read(), snapshot)
        let disconnected = FavoriteControlSnapshot(serverID: "test", favorites: [], connected: false)
        try store.write(disconnected)
        XCTAssertEqual(try store.read(), disconnected)
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("favorites.json").path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testExpiredFutureAndDisconnectedSnapshotsAreNotPresentedAsLive() {
        let now = Date(timeIntervalSince1970: 1000)
        func snapshot(_ age: Double, connected: Bool = true) -> FavoriteControlSnapshot {
            FavoriteControlSnapshot(serverID: "test", favorites: [], connected: connected, updatedAt: now.addingTimeInterval(-age))
        }
        XCTAssertTrue(ControlSharedStore.isFresh(snapshot(0), now: now))
        XCTAssertTrue(ControlSharedStore.isFresh(snapshot(89), now: now))
        XCTAssertFalse(ControlSharedStore.isFresh(snapshot(90), now: now))
        XCTAssertFalse(ControlSharedStore.isFresh(snapshot(-10), now: now))
        XCTAssertFalse(ControlSharedStore.isFresh(snapshot(0, connected: false), now: now))
    }
}
