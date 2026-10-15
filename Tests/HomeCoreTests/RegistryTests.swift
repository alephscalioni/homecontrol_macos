import XCTest
@testable import HomeCore

final class RegistryTests: XCTestCase {
    private var registry: HARegistry {
        HARegistry(areas: [HAArea(id: "office", name: "Escritório"), HAArea(id: "kitchen", name: "Cozinha")],
                   devices: [HADevice(id: "panel", name: "Painel", areaID: "office")],
                   entities: [HARegistryEntity(id: "switch.inherited", deviceID: "panel"),
                              HARegistryEntity(id: "switch.override", deviceID: "panel", areaID: "kitchen"),
                              HARegistryEntity(id: "scene.global")])
    }
    func testExplicitEntityAreaOverridesDeviceArea() {
        XCTAssertEqual(registry.effectiveAreaID(for: "switch.override"), "kitchen")
        XCTAssertEqual(registry.areaIDsByEntity["switch.override"], "kitchen")
        XCTAssertEqual(registry.entityAreaNames["switch.override"], "Cozinha")
    }
    func testNilEntityAreaInheritsFromDevice() {
        XCTAssertEqual(registry.effectiveAreaID(for: "switch.inherited"), "office")
        XCTAssertEqual(registry.areaIDsByEntity["switch.inherited"], "office")
    }
    func testGlobalItemsAreNotAssignedAnInventedRoom() {
        XCTAssertNil(registry.effectiveAreaID(for: "scene.global"))
        XCTAssertFalse(registry.matches("scene.global", scope: .unassigned))
        XCTAssertTrue(registry.matches("scene.global", scope: .general))
        XCTAssertFalse(registry.matches("scene.global", scope: .area("office")))
        XCTAssertTrue(registry.matches("scene.global", scope: .all))
    }
    func testRemovedAreaCannotAppearAsAnExistingRoom() {
        var value = registry
        value.areas.removeAll { $0.id == "kitchen" }
        XCTAssertNil(value.effectiveAreaID(for: "switch.override"))
        XCTAssertNil(value.areaIDsByEntity["switch.override"])
    }
    func testRenamingAreaKeepsStableAssignmentID() {
        var value = registry
        value.areas = [HAArea(id: "office", name: "Home office"), HAArea(id: "kitchen", name: "Cozinha")]
        XCTAssertEqual(value.areaIDsByEntity["switch.inherited"], "office")
        XCTAssertEqual(value.entityAreaNames["switch.inherited"], "Home office")
    }
    func testPlanFailsIfSomeoneChangedTheAreaAfterInventory() {
        let stale = AreaAssignment(kind: .device, id: "panel", name: "Painel", previousAreaID: nil, areaID: "kitchen", reason: "teste")
        XCTAssertThrowsError(try AreaAssignmentPlan(server: "http://test", changes: [stale]).validate(against: registry))
    }
    func testPlanFailsForMissingTargetOrDeletedEntity() {
        let missingRoom = AreaAssignment(kind: .device, id: "panel", name: "Painel", previousAreaID: "office", areaID: "deleted", reason: "teste")
        let deletedEntity = AreaAssignment(kind: .entity, id: "switch.deleted", name: "Removido", previousAreaID: nil, areaID: "office", reason: "teste")
        XCTAssertThrowsError(try AreaAssignmentPlan(server: "http://test", changes: [missingRoom]).validate(against: registry))
        XCTAssertThrowsError(try AreaAssignmentPlan(server: "http://test", changes: [deletedEntity]).validate(against: registry))
    }
    func testPlanRejectsDuplicateUpdates() {
        let change = AreaAssignment(kind: .device, id: "panel", name: "Painel", previousAreaID: "office", areaID: "kitchen", reason: "teste")
        XCTAssertThrowsError(try AreaAssignmentPlan(server: "http://test", changes: [change, change]).validate(against: registry))
    }
    func testAssignmentPayloadCannotRenameOrOperateADevice() throws {
        let change = AreaAssignment(kind: .entity, id: "switch.override", name: "Nome", previousAreaID: "kitchen", areaID: nil, reason: "herdar")
        XCTAssertEqual(change.payload, ["type": .string("config/entity_registry/update"), "entity_id": .string("switch.override"), "area_id": .null])
        XCTAssertEqual(change.reversed.previousAreaID, nil)
        XCTAssertEqual(change.reversed.areaID, "kitchen")
        try AreaAssignmentPlan(server: "http://test", changes: [change]).validate(against: registry)
    }
}
