import Foundation
import XCTest
@testable import HomeCore

final class ClimateWidgetStateTests: XCTestCase {
    private func climate(state: String = "cool", features: Double = 1,
                         extra: [String: JSONValue] = [:]) -> HAEntity {
        var attributes: [String: JSONValue] = [
            "supported_features": .number(features), "temperature": .number(22),
            "current_temperature": .number(23.5), "min_temp": .number(16),
            "max_temp": .number(30), "target_temp_step": .number(0.5)
        ]
        attributes.merge(extra) { _, value in value }
        return HAEntity("climate.test", state: state, attributes: attributes)
    }

    func testReportedStateAndWireValuesRoundTrip() throws {
        let entity = climate(state: "vendor_mode", extra: ["hvac_action": .string("vendor_action")])
        let state = ClimateWidgetState(entity: entity)
        XCTAssertEqual(state.target, 22)
        XCTAssertEqual(state.current, 23.5)
        XCTAssertEqual(state.unit, "°C")
        XCTAssertEqual(state.step, 0.5)
        XCTAssertEqual(state.minimum, 16)
        XCTAssertEqual(state.maximum, 30)
        XCTAssertEqual(state.mode, "vendor_mode")
        XCTAssertEqual(state.action, "vendor_action")
        XCTAssertTrue(state.isSingleTarget)
        XCTAssertTrue(state.canDecrease)
        XCTAssertTrue(state.canIncrease)
        XCTAssertEqual(try JSONDecoder().decode(ClimateWidgetState.self,
            from: JSONEncoder().encode(state)), state)
        let call = ServiceCall.adjustTemperature(entity, direction: 1)
        XCTAssertEqual(call, ServiceCall(entity, "set_temperature", data: ["temperature": .number(22.5)]))
        XCTAssertEqual(call?.payload["target"]?["entity_id"], .string("climate.test"))
        XCTAssertEqual(ServiceCall.adjustTemperature(entity, direction: -1)?.data,
                       ["temperature": .number(21.5)])
    }

    func testBoundariesClampAndDisableOnlyTheReachedDirection() {
        for (target, decrease, increase) in [(16.0, false, true), (30.0, true, false)] {
            let entity = climate(extra: ["temperature": .number(target)])
            let state = ClimateWidgetState(entity: entity)
            XCTAssertEqual(state.canDecrease, decrease)
            XCTAssertEqual(state.canIncrease, increase)
            XCTAssertEqual(ServiceCall.adjustTemperature(entity, direction: -1) != nil, decrease)
            XCTAssertEqual(ServiceCall.adjustTemperature(entity, direction: 1) != nil, increase)
        }
        let nearMaximum = climate(extra: ["temperature": .number(29.8)])
        XCTAssertEqual(ServiceCall.adjustTemperature(nearMaximum, direction: 1)?.data,
                       ["temperature": .number(30)])
    }

    func testSnappingIsRelativeToMinimumAndUsesReportedStep() {
        let entity = climate(extra: ["min_temp": .number(16.25), "temperature": .number(22.25)])
        XCTAssertEqual(ServiceCall.adjustTemperature(entity, direction: 1)?.data,
                       ["temperature": .number(22.75)])
        let wholeStep = climate(extra: ["target_temp_step": .number(2)])
        XCTAssertEqual(ServiceCall.adjustTemperature(wholeStep, direction: -1)?.data,
                       ["temperature": .number(20)])
    }

    func testUnitSpecificDefaultsAndFahrenheitWithoutConversion() {
        for (unit, target, step, minimum, maximum) in [
            ("°C", 22.0, 0.5, 7.0, 35.0), ("°F", 72.0, 1.0, 45.0, 95.0)
        ] {
            let entity = HAEntity("climate.test", state: "heat", attributes: [
                "supported_features": .number(1), "temperature": .number(target),
                "temperature_unit": .string(unit)
            ])
            let state = ClimateWidgetState(entity: entity)
            XCTAssertEqual(state.unit, unit)
            XCTAssertEqual(state.step, step)
            XCTAssertEqual(state.minimum, minimum)
            XCTAssertEqual(state.maximum, maximum)
            XCTAssertNil(state.current)
            XCTAssertNil(state.action)
            XCTAssertEqual(ServiceCall.adjustTemperature(entity, direction: 1)?.data,
                           ["temperature": .number(target + step)])
        }
    }

    func testRejectsMissingTargetUnavailableNonClimateAndRangeTargets() {
        var nonClimate = climate()
        nonClimate.entityID = "sensor.test"
        let rejected = [
            climate(extra: ["temperature": .null]), climate(state: "unavailable"),
            climate(state: "unknown"), nonClimate, climate(features: 0),
            climate(features: 2), climate(state: "heat_cool", features: 3),
            climate(state: "auto", features: 3)
        ]
        for entity in rejected {
            XCTAssertNil(ServiceCall.adjustTemperature(entity, direction: -1))
            XCTAssertNil(ServiceCall.adjustTemperature(entity, direction: 1))
            let state = ClimateWidgetState(entity: entity)
            XCTAssertFalse(state.canDecrease)
            XCTAssertFalse(state.canIncrease)
        }
        let range = climate(state: "heat_cool", features: 3, extra: [
            "target_temp_low": .number(20), "target_temp_high": .number(25)
        ])
        XCTAssertFalse(ClimateWidgetState(entity: range).isSingleTarget)
        XCTAssertNil(ServiceCall.adjustTemperature(range, direction: 1))
        XCTAssertTrue(ClimateWidgetState(entity: climate(state: "cool", features: 3)).isSingleTarget)
        for direction in [Int.min, -2, 0, 2, Int.max] {
            XCTAssertNil(ServiceCall.adjustTemperature(climate(), direction: direction))
        }
    }

    func testInvalidNumbersNeverProduceCommandsOrNonfiniteSnapshotValues() throws {
        for key in ["temperature", "min_temp", "max_temp", "target_temp_step", "supported_features"] {
            for value in [Double.nan, .infinity, -.infinity] {
                let entity = climate(extra: [key: .number(value)])
                XCTAssertNil(ServiceCall.adjustTemperature(entity, direction: -1), key)
                XCTAssertNil(ServiceCall.adjustTemperature(entity, direction: 1), key)
                let state = ClimateWidgetState(entity: entity)
                XCTAssertFalse(state.canDecrease)
                XCTAssertFalse(state.canIncrease)
                XCTAssertNoThrow(try JSONEncoder().encode(state))
            }
        }
        let invalidAttributes: [[String: JSONValue]] = [
            ["target_temp_step": .number(0)], ["target_temp_step": .number(-1)],
            ["min_temp": .number(31)], ["temperature": .number(15)],
            ["temperature": .number(31)], ["min_temp": .string("invalid")],
            ["supported_features": .number(Double.greatestFiniteMagnitude)]
        ]
        for extra in invalidAttributes {
            XCTAssertNil(ServiceCall.adjustTemperature(climate(extra: extra), direction: 1))
        }
        let entity = climate(extra: ["current_temperature": .number(.nan)])
        XCTAssertNil(ClimateWidgetState(entity: entity).current)
        XCTAssertNotNil(ServiceCall.adjustTemperature(entity, direction: 1))
    }

    func testPowerAvailabilityMatchesSetPowerWithoutInferringMode() {
        for features in [0.0, 1, 128, 256, 384] {
            for mode in ["off", "cool", "unavailable", "unknown"] {
                for modes in [["off", "heat", "cool"], ["desligado", "cool"], []] {
                    let entity = climate(state: mode, features: features, extra: ["hvac_modes": .strings(modes)])
                    let state = ClimateWidgetState(entity: entity)
                    XCTAssertEqual(state.canPowerOn, ServiceCall.setPower(entity, isOn: true) != nil)
                    XCTAssertEqual(state.canPowerOff, ServiceCall.setPower(entity, isOn: false) != nil)
                }
            }
        }
        let off = climate(state: "off", extra: ["hvac_modes": .strings(["off", "heat", "cool"])])
        XCTAssertFalse(ClimateWidgetState(entity: off).canPowerOn)
        let fallback = climate(extra: ["hvac_modes": .strings(["off", "cool"])])
        XCTAssertTrue(ClimateWidgetState(entity: fallback).canPowerOff)
        XCTAssertEqual(ServiceCall.setPower(fallback, isOn: false)?.data, ["hvac_mode": .string("off")])
        let nonClimate = HAEntity("light.test", state: "off", attributes: [:])
        XCTAssertFalse(ClimateWidgetState(entity: nonClimate).canPowerOn)
        XCTAssertFalse(ClimateWidgetState(entity: nonClimate).canPowerOff)
    }
}
