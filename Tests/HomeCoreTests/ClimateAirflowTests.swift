import XCTest
@testable import HomeCore

final class ClimateAirflowTests: XCTestCase {
    private func climate(_ mode: String = "auto", state: String = "cool", extra: [String: JSONValue] = [:]) -> HAEntity {
        var attributes: [String: JSONValue] = ["fan_mode": .string(mode)]
        attributes.merge(extra) { _, value in value }
        return HAEntity("climate.test", state: state, attributes: attributes)
    }

    func testOffAndUnavailableDevicesNeverProduceAirflow() {
        for state in ["off", "unavailable", "unknown"] {
            XCTAssertEqual(ClimateAirflow(entity: climate("high", state: state)), .stopped)
        }
        XCTAssertEqual(ClimateAirflow(entity: HAEntity("light.test", state: "on", attributes: [:])), .stopped)
    }

    func testReportedSpeedControlsStrength() {
        let low = ClimateAirflow(entity: climate("low"))
        let medium = ClimateAirflow(entity: climate("medium"))
        let high = ClimateAirflow(entity: climate("high"))
        XCTAssertGreaterThan(low.strength, 0)
        XCTAssertLessThan(low.strength, medium.strength)
        XCTAssertLessThan(medium.strength, high.strength)
        XCTAssertLessThan(high.strength, ClimateAirflow(entity: climate("turbo")).strength)
        XCTAssertLessThan(ClimateAirflow(entity: climate("silent")).strength, low.strength)
        XCTAssertFalse(ClimateAirflow(entity: climate("off")).isRunning)
    }

    func testPercentageAndNumericFanSteps() {
        XCTAssertEqual(ClimateAirflow(entity: climate("25%")).strength, 0.25)
        XCTAssertEqual(ClimateAirflow(entity: climate(extra: ["fan_percentage": .number(75)])).strength, 0.75)
        XCTAssertEqual(ClimateAirflow(entity: climate(extra: ["fan_percentage": .number(140)])).strength, 1)
        XCTAssertEqual(ClimateAirflow(entity: climate(extra: ["fan_percentage": .number(-10)])).strength, 0)
        let modes: JSONValue = .strings(["auto", "1", "2", "3", "4"])
        XCTAssertEqual(ClimateAirflow(entity: climate("2", extra: ["fan_modes": modes])).strength, 0.5)
    }

    func testLabelsAreNormalizedWithoutDependingOnInterfaceLanguage() {
        XCTAssertEqual(ClimateAirflow(entity: climate(" HIGH ")).strength, ClimateAirflow(entity: climate("alta")).strength)
        XCTAssertEqual(ClimateAirflow(entity: climate("média")).strength, ClimateAirflow(entity: climate("medium")).strength)
        let automatic = ClimateAirflow(entity: climate())
        XCTAssertTrue(automatic.isRunning)
        XCTAssertEqual(ClimateAirflow(entity: climate("custom mode")).strength, automatic.strength)
    }

    func testOnlyReportedHorizontalSwingSweepsTheFlow() {
        XCTAssertFalse(ClimateAirflow(entity: climate(extra: ["swing_mode": .string("vertical")])).sweepsHorizontally)
        XCTAssertTrue(ClimateAirflow(entity: climate(extra: ["swing_mode": .string("both")])).sweepsHorizontally)
        XCTAssertTrue(ClimateAirflow(entity: climate(extra: ["swing_horizontal_mode": .string("on")])).sweepsHorizontally)
        XCTAssertFalse(ClimateAirflow(entity: climate(extra: ["swing_mode": .string("unknown")])).sweepsHorizontally)
    }
}
