import XCTest
@testable import HomeCore

final class EntityTests: XCTestCase {
    func testServerAddressesPreserveReverseProxyPaths() throws {
        let base = try ServerAddress.normalize("  https://example.com/home/  ")
        XCTAssertEqual(base.absoluteString, "https://example.com/home")
        XCTAssertEqual(ServerAddress.websocket(base).absoluteString, "wss://example.com/home/api/websocket")
        XCTAssertEqual(ServerAddress.websocket(try ServerAddress.normalize("http://homeassistant.local:8123")).absoluteString, "ws://homeassistant.local:8123/api/websocket")
    }
    func testRejectsCredentialBearingAndInvalidAddresses() {
        for address in ["homeassistant.local", "file:///tmp/test", "https://user:secret@example.com", "https://example.com?token=secret", "https://example.com#token", "https://"] {
            XCTAssertThrowsError(try ServerAddress.normalize(address), address)
        }
    }
    func testClimateDoesNotGuessModeWhenTurnOnIsUnsupported() {
        let entity = HAEntity("climate.test", state: "off", attributes: ["hvac_modes": .strings(["off", "heat", "cool"]), "supported_features": .number(1)])
        XCTAssertNil(ServiceCall.power(entity))
        var on = entity; on.state = "cool"
        XCTAssertEqual(ServiceCall.power(on)?.service, "set_hvac_mode")
        XCTAssertEqual(ServiceCall.power(on)?.data["hvac_mode"], .string("off"))
    }
    func testClimateRespectsNativePowerSupport() {
        let entity = HAEntity("climate.test", state: "off", attributes: ["supported_features": .number(384)])
        XCTAssertEqual(ServiceCall.power(entity)?.service, "turn_on")
        var on = entity; on.state = "heat"
        XCTAssertEqual(ServiceCall.power(on)?.service, "turn_off")
        on.state = "unavailable"
        XCTAssertNil(ServiceCall.power(on))
    }
    func testTemperatureClampsAndSnapsAgainstDeviceMinimum() {
        let entity = HAEntity("climate.test", state: "cool", attributes: ["supported_features": .number(1), "min_temp": .number(16), "max_temp": .number(30), "target_temp_step": .number(0.5)])
        XCTAssertEqual(ServiceCall.temperature(entity, value: 21.3)?.data["temperature"], .number(21.5))
        XCTAssertEqual(ServiceCall.temperature(entity, value: 50)?.data["temperature"], .number(30))
        XCTAssertEqual(ServiceCall.temperature(entity, value: -10)?.data["temperature"], .number(16))
        XCTAssertNil(ServiceCall.temperature(entity, value: .nan))
    }
    func testRangeTemperatureNeverSendsSingleSetpointOrCrossesBounds() {
        let entity = HAEntity("climate.test", state: "heat_cool", attributes: ["supported_features": .number(3), "min_temp": .number(16), "max_temp": .number(30), "target_temp_low": .number(20), "target_temp_high": .number(25)])
        XCTAssertNil(ServiceCall.temperature(entity, value: 22))
        let command = ServiceCall.temperature(entity, value: 28, high: false)
        XCTAssertNil(command?.data["temperature"])
        XCTAssertEqual(command?.data["target_temp_low"], .number(25))
        XCTAssertEqual(command?.data["target_temp_high"], .number(25))
    }
    func testOnOffLightDoesNotClaimDimmingSupport() {
        let simple = HAEntity("light.test", state: "off", attributes: ["supported_color_modes": .strings(["onoff"])])
        XCTAssertFalse(simple.supportsBrightness)
        var dimmable = simple; dimmable.attributes["supported_color_modes"] = .strings(["rgb"])
        XCTAssertTrue(dimmable.supportsBrightness)
    }
    func testExcludesGarageDoorsAndSecurityEntities() {
        XCTAssertFalse(HAEntity("cover.garage", state: "closed", attributes: ["device_class": .string("garage")]).isSupported)
        XCTAssertFalse(HAEntity("lock.front", state: "locked", attributes: [:]).isSupported)
        XCTAssertTrue(HAEntity("cover.curtain", state: "closed", attributes: ["device_class": .string("curtain")]).isSupported)
    }
    func testJSONPreservesBooleanNumbersAndNull() throws {
        let data = Data("{\"entity_id\":\"climate.test\",\"state\":\"cool\",\"attributes\":{\"temperature\":21.5,\"enabled\":true,\"preset_mode\":null}}".utf8)
        let entity = try JSONDecoder().decode(HAEntity.self, from: data)
        XCTAssertEqual(entity.number("temperature"), 21.5)
        XCTAssertEqual(entity.attributes["enabled"], .bool(true))
        XCTAssertNil(entity.text("preset_mode"))
        XCTAssertEqual(try JSONDecoder().decode(HAEntity.self, from: JSONEncoder().encode(entity)), entity)
    }
    func testServiceCallTargetsOnlySelectedEntity() {
        let entity = HAEntity("light.test", state: "on", attributes: [:])
        let call = ServiceCall(entity, "turn_on", data: ["brightness_pct": .number(70)])
        XCTAssertEqual(call.payload["target"]?["entity_id"], .string("light.test"))
        XCTAssertEqual(call.payload["service_data"]?["brightness_pct"], .number(70))
    }
}
