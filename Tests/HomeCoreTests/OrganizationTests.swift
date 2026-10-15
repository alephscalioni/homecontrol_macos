import XCTest
@testable import HomeCore

final class OrganizationTests: XCTestCase {
    private func sensor(_ id: String = "sensor.reading", _ deviceClass: String? = nil, unit: String? = nil) -> HAEntity {
        var attributes: [String: JSONValue] = [:]
        attributes["device_class"] = deviceClass.map(JSONValue.string)
        attributes["unit_of_measurement"] = unit.map(JSONValue.string)
        return HAEntity(id, state: "12.4", attributes: attributes)
    }
    func testEnergyAndInstantaneousPowerAreDifferentMetrics() {
        let energy = sensor("sensor.air_energy_this_month", "energy", unit: "kWh")
        let power = sensor("sensor.air_power", "power", unit: "W")
        XCTAssertEqual(EntityOrganizer.purpose(for: energy), .consumption)
        XCTAssertEqual(EntityOrganizer.purpose(for: power), .consumption)
        XCTAssertEqual(ConsumptionMetric.classify(energy), .energy)
        XCTAssertEqual(ConsumptionMetric.classify(power), .power)
        XCTAssertEqual(ConsumptionMetric.period(energy), "Este mês")
        XCTAssertNil(ConsumptionMetric.period(power))
    }
    func testElectricalTelemetryIsNotAnEnvironmentReading() {
        for deviceClass in ["current", "voltage", "power_factor", "frequency"] {
            let entity = sensor("sensor.meter", deviceClass)
            XCTAssertEqual(EntityOrganizer.purpose(for: entity), .consumption)
            XCTAssertEqual(ConsumptionMetric.classify(entity), .electrical)
        }
    }
    func testGasLeakIsSafetyWhileGasVolumeIsConsumption() {
        let leak = HAEntity("binary_sensor.gas", state: "off", attributes: ["device_class": .string("gas")])
        XCTAssertEqual(EntityOrganizer.purpose(for: leak), .environment)
        XCTAssertEqual(EntityOrganizer.purpose(for: sensor("sensor.gas", "gas", unit: "m³")), .consumption)
    }
    func testRegistryConfigurationTakesPriorityOverMisleadingNames() {
        let entity = HAEntity("switch.air_economia_de_energia", state: "on", attributes: [:])
        XCTAssertEqual(EntityOrganizer.purpose(for: entity, entry: HARegistryEntity(id: entity.id, category: "config")), .configuration)
    }
    func testBatteryAndFilterLifeBelongToMaintenance() {
        let battery = sensor("sensor.robot_battery", "battery", unit: "%")
        XCTAssertEqual(EntityOrganizer.purpose(for: battery, entry: HARegistryEntity(id: battery.id, category: "diagnostic")), .maintenance)
        XCTAssertEqual(EntityOrganizer.purpose(for: sensor("sensor.air_filter_remaining")), .maintenance)
        XCTAssertEqual(EntityOrganizer.purpose(for: sensor("sensor.robot_vida_util_do_filtro")), .maintenance)
    }
    func testConnectionAndBackupAreDiagnostics() {
        XCTAssertEqual(EntityOrganizer.purpose(for: sensor("sensor.rssi", "signal_strength")), .diagnostics)
        let backup = sensor("sensor.backup_next")
        XCTAssertEqual(EntityOrganizer.purpose(for: backup, entry: HARegistryEntity(id: backup.id, platform: "backup")), .diagnostics)
    }
    func testTimersAndDNDDoNotClutterEverydayControls() {
        XCTAssertEqual(EntityOrganizer.purpose(for: sensor("sensor.air_schedule_turn_off")), .routines)
        XCTAssertEqual(EntityOrganizer.purpose(for: sensor("sensor.speaker_next_alarm")), .routines)
        let dnd = HAEntity("switch.speaker_do_not_disturb", state: "off", attributes: [:])
        XCTAssertEqual(EntityOrganizer.purpose(for: dnd), .configuration)
    }
    func testUnknownSensorStaysDiscoverableWithoutGuessingItsMeaning() {
        XCTAssertEqual(EntityOrganizer.purpose(for: sensor("sensor.mystery")), .other)
        XCTAssertEqual(EntityOrganizer.purpose(for: sensor("sensor.temperature", "temperature")), .environment)
    }
    func testPrimarySwitchAndSceneRemainEverydayControls() {
        for id in ["switch.office", "climate.office", "light.desk", "scene.cinema"] {
            XCTAssertTrue(EntityOrganizer.purpose(for: HAEntity(id, state: "off", attributes: [:])).isEveryday)
        }
    }
    func testManualClassificationWinsWithoutChangingTheEntity() {
        let original = sensor("sensor.mystery")
        XCTAssertEqual(EntityOrganizer.purpose(for: original, override: .environment), .environment)
        XCTAssertEqual(EntityOrganizer.purpose(for: original), .other)
        XCTAssertEqual(original.state, "12.4")
        XCTAssertEqual(original.id, "sensor.mystery")
    }
    func testHidingIsReversibleAndRespectsHAHiddenEntities() {
        let entity = sensor()
        var preferences = OrganizationPreferences()
        preferences.hiddenIDs.insert(entity.id)
        XCTAssertTrue(preferences.isHidden(entity, entry: nil))
        preferences.hiddenIDs.remove(entity.id)
        XCTAssertFalse(preferences.isHidden(entity, entry: nil))
        XCTAssertTrue(preferences.isHidden(entity, entry: HARegistryEntity(id: entity.id, hiddenBy: "user")))
        XCTAssertTrue(preferences.isHidden(entity, entry: HARegistryEntity(id: entity.id, disabledBy: "integration")))
    }
    func testPreferencesPreserveStableIDsAcrossRelaunch() throws {
        var preferences = OrganizationPreferences()
        preferences.purposes["sensor.mystery"] = .environment
        preferences.hiddenIDs = ["switch.unused"]
        let restored = try JSONDecoder().decode(OrganizationPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(restored, preferences)
    }
    func testGeneralServicesAreSeparateFromUnknownPhysicalLocations() {
        XCTAssertTrue(EntityOrganizer.isGeneral(entityID: "scene.cinema", entry: nil))
        XCTAssertTrue(EntityOrganizer.isGeneral(entityID: "sensor.backup", entry: HARegistryEntity(id: "sensor.backup", platform: "backup")))
        XCTAssertFalse(EntityOrganizer.isGeneral(entityID: "switch.desk", entry: nil))
    }
    func testPeriodsAreNotInventedForAnUnknownCounter() {
        XCTAssertNil(ConsumptionMetric.period(sensor("sensor.energy", "energy", unit: "kWh")))
        XCTAssertEqual(ConsumptionMetric.period(sensor("sensor.air_energy_last_month")), "Mês passado")
        XCTAssertEqual(ConsumptionMetric.period(sensor("sensor.air_energy_yesterday")), "Ontem")
    }
}
