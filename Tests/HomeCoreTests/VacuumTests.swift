import XCTest
@testable import HomeCore

final class VacuumTests: XCTestCase {
    private func robot(_ state: String = "docked", flags: Double = 12828) -> HAEntity {
        HAEntity("vacuum.robot", state: state, attributes: ["supported_features": .number(flags)])
    }
    private func entry(_ id: String, device: String = "robot", platform: String = "xiaomi_home") -> HARegistryEntity {
        HARegistryEntity(id: id, deviceID: device, platform: platform)
    }
    private func map(_ names: String = "") throws -> VacuumRoomMap {
        try XCTUnwrap(VacuumRoomMap(entity: HAEntity("sensor.robot_room_information_p_2_16", state: "{\"map_uid\":1,\"rooms\":[{\"id\":3,\"name\":\"\(names)\"},{\"id\":7,\"name\":\"Bedroom\"}]}", attributes: [:])))
    }
    func testVacuumHasNoPowerToggleAndActionsRespectActivity() {
        XCTAssertTrue(robot().isSupported)
        XCTAssertNil(ServiceCall.power(robot()))
        XCTAssertEqual(VacuumAction.start.command(for: robot())?.service, "start")
        XCTAssertNil(VacuumAction.start.command(for: robot("cleaning")))
        XCTAssertNil(VacuumAction.pause.command(for: robot()))
        XCTAssertEqual(VacuumAction.pause.command(for: robot("cleaning"))?.service, "pause")
        XCTAssertEqual(VacuumAction.start.command(for: robot("paused"))?.service, "start")
        XCTAssertNil(VacuumAction.returnToBase.command(for: robot()))
        XCTAssertEqual(VacuumAction.returnToBase.command(for: robot("idle"))?.service, "return_to_base")
        XCTAssertNil(VacuumAction.stop.command(for: robot()))
        XCTAssertEqual(VacuumAction.stop.command(for: robot("returning"))?.service, "stop")
    }
    func testInvalidOrUnsupportedFeaturesCannotCreateACommand() {
        for flags in [0, -1, .infinity, .nan, Double(Int.max), 12828.5] {
            XCTAssertNil(VacuumAction.start.command(for: robot(flags: flags)))
        }
        XCTAssertNil(VacuumAction.start.command(for: robot("unavailable")))
        XCTAssertNil(VacuumAction.start.command(for: HAEntity("switch.robot", state: "on", attributes: ["supported_features": .number(8192)])))
    }
    func testStandardSuctionRequiresAdvertisedFeatureAndExactOption() {
        var r = robot(flags: 8192 + 32)
        r.attributes["fan_speed_list"] = .strings(["quiet", "turbo"])
        XCTAssertEqual(VacuumOrganization.suction(r, speed: "turbo")?.data, ["fan_speed": .string("turbo")])
        XCTAssertNil(VacuumOrganization.suction(r, speed: "guess"))
        r.attributes["supported_features"] = .number(8192)
        XCTAssertNil(VacuumOrganization.suction(r, speed: "turbo"))
    }
    func testMembershipUsesDeviceIDInsteadOfNameAndSurvivesRenames() {
        let r = robot(), child = HAEntity("switch.carpet", state: "off", attributes: [:]), unrelated = HAEntity("switch.robot_copy", state: "on", attributes: [:])
        let entries = [r.id: entry(r.id), child.id: entry(child.id), unrelated.id: entry(unrelated.id, device: "other")]
        let owners = VacuumOrganization.owners(entities: [r, child, unrelated], entries: entries)
        XCTAssertEqual(owners, [child.id: r.id])
        var renamed = child; renamed.attributes["friendly_name"] = .string("A new name")
        XCTAssertEqual(VacuumOrganization.owners(entities: [r, renamed, unrelated], entries: entries), owners)
    }
    func testAmbiguousOrMissingRegistryNeverSwallowsEntities() {
        let r = robot(), second = HAEntity("vacuum.second", state: "docked", attributes: [:]), child = HAEntity("switch.carpet", state: "off", attributes: [:])
        XCTAssertTrue(VacuumOrganization.owners(entities: [r, child], entries: [:]).isEmpty)
        let entries = [r.id: entry(r.id), second.id: entry(second.id), child.id: entry(child.id)]
        XCTAssertTrue(VacuumOrganization.owners(entities: [r, second, child], entries: entries).isEmpty)
    }
    func testConsolidationRequiresAVisibleOwnerInTheSameScopeAndNoManualOverride() {
        let child = HAEntity("switch.carpet", state: "off", attributes: [:]), owners = ["switch.carpet": "vacuum.robot"]
        var preferences = OrganizationPreferences()
        XCTAssertFalse(VacuumOrganization.isConsolidated(child, owners: owners, visibleIDs: [], preferences: preferences))
        XCTAssertTrue(VacuumOrganization.isConsolidated(child, owners: owners, visibleIDs: ["vacuum.robot"], preferences: preferences))
        preferences.purposes[child.id] = .controls
        XCTAssertFalse(VacuumOrganization.isConsolidated(child, owners: owners, visibleIDs: ["vacuum.robot"], preferences: preferences))
    }
    func testVacuumSettingsDoNotFloodEverydayControlsAndOverridesStillWin() {
        let carpet = HAEntity("switch.robot_carpet_boost_p_2_20", state: "on", attributes: [:])
        XCTAssertEqual(VacuumOrganization.section(for: carpet), .navigation)
        XCTAssertEqual(VacuumOrganization.purpose(for: carpet), .configuration)
        XCTAssertEqual(VacuumOrganization.purpose(for: carpet, override: .controls), .controls)
        XCTAssertEqual(VacuumOrganization.section(for: carpet, override: .maintenance), .maintenance)
        XCTAssertEqual(VacuumOrganization.section(for: HAEntity("sensor.robot_filter_life_level_p_14_1", state: "90", attributes: [:])), .maintenance)
        XCTAssertEqual(VacuumOrganization.section(for: HAEntity("sensor.robot_map_obj_name_p_10_1", state: "{}", attributes: [:])), .advanced)
        XCTAssertEqual(VacuumOrganization.section(for: HAEntity("switch.robot_visible_to_shared_users_p_21_5", state: "off", attributes: ["friendly_name": .string("Stream Management Visible to Shared Users")])), .advanced)
    }
    func testNeverUsedActionIsAvailableWhileUnavailableActionStaysDisabled() {
        XCTAssertTrue(HAEntity("button.robot_start_dry", state: "unknown", attributes: [:]).available)
        XCTAssertTrue(HAEntity("notify.robot_action", state: "unknown", attributes: [:]).available)
        XCTAssertFalse(HAEntity("button.robot_start_dry", state: "unavailable", attributes: [:]).available)
        XCTAssertFalse(HAEntity("sensor.robot", state: "unknown", attributes: [:]).available)
    }
    func testDockAllowlistExcludesMapResetRemoteAndCredentialActions() {
        let empty = HAEntity("button.robot_start_dust_arrest_a_2_18", state: "unknown", attributes: [:])
        XCTAssertEqual(VacuumDockAction.emptyDust.command(for: empty)?.service, "press")
        XCTAssertEqual(VacuumOrganization.section(for: empty), .dock)
        for name in ["reset_filter_life", "clear_map", "forgot_password", "enter_remote", "imu_calibration"] {
            let item = HAEntity("button.robot_\(name)_a_2_1", state: "unknown", attributes: [:])
            XCTAssertFalse(VacuumDockAction.allCases.contains { $0.matches(item) })
            XCTAssertEqual(VacuumOrganization.section(for: item), .advanced)
        }
    }
    func testRoomNamesRefreshWithStableMapIDs() throws {
        let old = try map(), updated = try map("Kitchen")
        XCTAssertEqual(old.rooms.map(\.id), updated.rooms.map(\.id))
        XCTAssertEqual(old.rooms.first?.name, "")
        XCTAssertEqual(updated.rooms.first?.name, "Kitchen")
        XCTAssertEqual(old.mapID, updated.mapID)
    }
    func testSelectedRoomPayloadIsOneQuotedStringAndNeverFallsBackToAllRooms() throws {
        let m = try map(), action = HAEntity("notify.robot_start_vacuum_room_sweep_a_2_16", state: "unknown", attributes: ["action params": .string("[Vacuum Room IDs(str)]")])
        let one = try XCTUnwrap(m.command(selectedIDs: ["3"], action: action, entry: entry(action.id)))
        XCTAssertEqual(one.data, ["message": .string("'3'")])
        XCTAssertEqual(one.domain, "notify"); XCTAssertEqual(one.service, "send_message")
        XCTAssertEqual(m.command(selectedIDs: ["7", "3"], action: action, entry: entry(action.id))?.data, ["message": .string("'3,7'")])
        XCTAssertNil(m.command(selectedIDs: [], action: action, entry: entry(action.id)))
        XCTAssertNil(m.command(selectedIDs: ["99"], action: action, entry: entry(action.id)))
        XCTAssertNil(m.command(selectedIDs: ["3"], action: action, entry: entry(action.id, platform: "other")))
        var wrongSchema = action; wrongSchema.attributes["action params"] = .string("[Other(int), IDs(str)]")
        XCTAssertNil(m.command(selectedIDs: ["3"], action: wrongSchema, entry: entry(action.id)))
    }
    func testRoomParserRejectsMalformedIDsAndDeduplicates() throws {
        let state = "{\"map_uid\":2,\"rooms\":[{\"id\":3,\"name\":\"Kitchen\"},{\"id\":3},{\"id\":\"3,7\"},{\"id\":-1}]}"
        let parsed = try XCTUnwrap(VacuumRoomMap(entity: HAEntity("sensor.robot_room_information", state: state, attributes: [:])))
        XCTAssertEqual(parsed.rooms.count, 1)
        XCTAssertNil(VacuumRoomMap(entity: HAEntity("sensor.robot_room_information", state: "{}", attributes: [:])))
        XCTAssertNil(VacuumRoomMap(entity: HAEntity("sensor.robot_room_information", state: "{\"rooms\":[{\"id\":3}]}", attributes: [:])))
    }
    func testScalarSettingsValidateOptionsBoundsAndEncodedProtocolNumbers() throws {
        let select = HAEntity("select.robot_suction", state: "Silent", attributes: ["options": .strings(["Silent", "Turbo"])])
        XCTAssertEqual(VacuumOrganization.setting(select, option: "Turbo")?.data, ["option": .string("Turbo")])
        XCTAssertNil(VacuumOrganization.setting(select, option: "Guess"))
        let volume = HAEntity("number.robot_volume", state: "20", attributes: ["min": .number(0), "max": .number(100), "step": .number(5)])
        XCTAssertEqual(VacuumOrganization.setting(volume, number: 23)?.data, ["value": .number(25)])
        XCTAssertEqual(VacuumOrganization.setting(volume, number: 1000)?.data, ["value": .number(100)])
        XCTAssertNil(VacuumOrganization.setting(volume, number: .nan))
        let encoded = HAEntity("number.robot_enable_time_period", state: "369100800", attributes: ["min": .number(0), "max": .number(4294967295), "step": .number(1)])
        XCTAssertNil(VacuumOrganization.numberBounds(encoded))
    }
    func testVacuumSearchAliasesAndEnglishPortugueseLabels() {
        let control = FavoriteControl(entity: robot(), serverID: "test")
        XCTAssertTrue(HomeWidgetSelection.matches(control, query: "aspirador"))
        XCTAssertTrue(HomeWidgetSelection.matches(control, query: "vacuum"))
        XCTAssertFalse(HomeWidgetSelection.supports(control))
        XCTAssertEqual(L10n.text("Cuidados com a base", locale: Locale(identifier: "en_US")), "Dock care")
        XCTAssertEqual(L10n.text("Cuidados com a base", locale: Locale(identifier: "pt_BR")), "Cuidados com a base")
    }
    func testRobotCameraKeepsItsOwnViewerAndOtherDevicesStayIndependent() {
        let r = robot(), camera = HAEntity("camera.robot", state: "idle", attributes: [:])
        let owners = VacuumOrganization.owners(entities: [r, camera], entries: [r.id: entry(r.id), camera.id: entry(camera.id)])
        XCTAssertNil(owners[camera.id])
    }
    func testPendingRoomOrDockCommandBlocksTheWholeRobotOnly() {
        let owners = ["notify.rooms": "vacuum.robot", "button.dock": "vacuum.robot", "button.other": "vacuum.other"]
        for pending in ["notify.rooms", "button.dock", "vacuum.robot"] {
            XCTAssertTrue(VacuumOrganization.isBusy(robotID: "vacuum.robot", owners: owners, pendingIDs: [pending]))
        }
        XCTAssertFalse(VacuumOrganization.isBusy(robotID: "vacuum.robot", owners: owners, pendingIDs: ["button.other"]))
    }
    func testGenericModeNamesAreNotMistakenForSuction() {
        let carpet = HAEntity("select.robot_carpet_cleaning_mode", state: "Auto", attributes: ["options": .strings(["Auto", "Avoid"])])
        XCTAssertFalse(VacuumOrganization.isPrimarySetting(carpet))
        XCTAssertFalse(VacuumOrganization.isSuctionSetting(carpet))
        XCTAssertEqual(VacuumOrganization.section(for: carpet), .navigation)
        let suction = HAEntity("select.robot_mode_p_2_9", state: "Standard", attributes: ["options": .strings(["Silent", "Standard", "Strong", "Turbo"])])
        XCTAssertTrue(VacuumOrganization.isPrimarySetting(suction))
        XCTAssertTrue(VacuumOrganization.isSuctionSetting(suction))
    }
}
