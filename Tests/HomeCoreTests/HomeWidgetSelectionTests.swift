import Foundation
import XCTest
@testable import HomeCore

final class HomeWidgetSelectionTests: XCTestCase {
    private func control(_ id: String, server: String = "test", state: String = "off", features: Double? = nil) -> FavoriteControl {
        var attributes: [String: JSONValue] = ["friendly_name": .string(id)]
        if let features { attributes["supported_features"] = .number(features) }
        return FavoriteControl(entity: HAEntity(id, state: state, attributes: attributes), serverID: server)
    }

    func testFourUniqueItemsPreserveUserOrder() {
        XCTAssertEqual(HomeWidgetSelection.identifiers(["b", "", "a", "b", "c", "d", "e"]), ["b", "a", "c", "d"])
        XCTAssertEqual(HomeWidgetSelection.identifiers([]), [])
    }

    func testReplacingItemInFullWidgetKeepsItsPositionWithoutRemovingFirst() {
        let selected = ["climate.room", "switch.desk", "scene.night", "fan.office"]
        XCTAssertEqual(HomeWidgetSelection.select("light.room", replacing: "switch.desk", in: selected),
                       ["climate.room", "light.room", "scene.night", "fan.office"])
        XCTAssertEqual(HomeWidgetSelection.select("light.room", replacing: nil, in: selected), selected)
        XCTAssertEqual(HomeWidgetSelection.select("scene.night", replacing: "switch.desk", in: selected), selected)
        XCTAssertEqual(HomeWidgetSelection.select("light.room", replacing: "climate.room", in: ["climate.room"], limit: 1), ["light.room"])
    }

    func testSearchFindsLightsByTypeWhenTheirNamesDoNotSayLight() {
        let light = FavoriteControl(entity: HAEntity("light.reading", state: "on", attributes: ["friendly_name": .string("Aurora")]),
                                    serverID: "test", room: "Escritório")
        XCTAssertTrue(HomeWidgetSelection.matches(light, query: "luzes escritorio"))
        XCTAssertTrue(HomeWidgetSelection.matches(light, query: "LIGHTS Aurora"))
        XCTAssertTrue(HomeWidgetSelection.matches(light, query: ""))
        XCTAssertFalse(HomeWidgetSelection.matches(light, query: "tomadas"))
        XCTAssertTrue(HomeWidgetSelection.matches(control("switch.desk"), query: "tomadas"))
        XCTAssertTrue(HomeWidgetSelection.matches(control("scene.night"), query: "cenas"))
    }

    func testRemovedOrOtherAccountItemsKeepTheirSlotWithoutRetargeting() {
        let light = control("light.room")
        let scene = control("scene.night")
        let oldAccount = control("light.room", server: "old")
        let snapshot = FavoriteControlSnapshot(serverID: "test", favorites: [], connected: true, controls: [light, scene])
        XCTAssertEqual(HomeWidgetSelection.resolve([scene.id, oldAccount.id, light.id], in: snapshot), [scene, nil, light])
        XCTAssertEqual(HomeWidgetSelection.resolve([], in: snapshot), [])
    }

    func testPickerOffersControllableItemsWithoutRequiringFavorites() {
        let light = control("light.room")
        let scene = control("scene.night")
        let offline = control("switch.desk", state: "unavailable")
        let temperatureOnly = control("climate.room", features: 1)
        let sensor = control("sensor.energy")
        let unsafe = control("lock.door")
        let unknownFan = control("fan.room")
        let snapshot = FavoriteControlSnapshot(serverID: "test", favorites: [], connected: true,
                                              controls: [light, scene, offline, temperatureOnly, sensor, unsafe, unknownFan, light])
        XCTAssertEqual(HomeWidgetSelection.options(in: snapshot), [light, scene, offline, temperatureOnly])
        XCTAssertFalse(offline.available)
    }

    func testOptionalControlCollectionRoundTripsAndOldSnapshotsRemainReadable() throws {
        let light = control("light.room")
        let snapshot = FavoriteControlSnapshot(serverID: "test", favorites: [], connected: true, controls: [light])
        let data = try JSONEncoder().encode(snapshot)
        XCTAssertEqual(try JSONDecoder().decode(FavoriteControlSnapshot.self, from: data).controls, [light])
        let old = FavoriteControlSnapshot(serverID: "test", favorites: [light], connected: true)
        let restored = try JSONDecoder().decode(FavoriteControlSnapshot.self, from: JSONEncoder().encode(old))
        XCTAssertNil(restored.controls)
        XCTAssertEqual(HomeWidgetSelection.options(in: restored), [light])
    }
}
