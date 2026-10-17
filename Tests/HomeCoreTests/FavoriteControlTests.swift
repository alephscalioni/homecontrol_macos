import Foundation
import XCTest
@testable import HomeCore

final class FavoriteControlTests: XCTestCase {
    func testMalformedFeatureMasksDoNotCrashSharedClimateSnapshots() throws {
        for mask in [JSONValue.number(.infinity), .number(.nan), .number(Double(Int.max)), .number(-1), .string("invalid")] {
            let entity = HAEntity("climate.sample", state: "cool", attributes: ["supported_features": mask])
            let favorite = FavoriteControl(entity: entity, serverID: "sample")
            XCTAssertEqual(favorite.kind, .open)
            XCTAssertFalse(favorite.climate?.isSingleTarget ?? true)
            XCTAssertNil(ServiceCall.setPower(entity, isOn: false))
            XCTAssertNoThrow(try JSONEncoder().encode(favorite))
        }
    }

    private func entity(_ domain: String, state: String = "off", features: Int = 0,
                        modes: [String] = []) -> HAEntity {
        HAEntity("\(domain).test", state: state, attributes: [
            "friendly_name": .string("Living room"),
            "supported_features": .number(Double(features)),
            "hvac_modes": .strings(modes)
        ])
    }

    func testIDsAreScopedAndSeparatorSafe() {
        let light = entity("light")
        let first = FavoriteControl(entity: light, serverID: "account-one")
        XCTAssertNotEqual(first.id, FavoriteControl(entity: light, serverID: "account-two").id)
        XCTAssertEqual(first.id, FavoriteControl(entity: light, serverID: "account-one").id)
        let left = FavoriteControl(entity: HAEntity("b|light.test", state: "off", attributes: [:]), serverID: "a")
        let right = FavoriteControl(entity: light, serverID: "a|b")
        XCTAssertNotEqual(left.id, right.id)
        XCTAssertNotEqual(right.id, FavoriteControl(entity: light, serverID: "a%7Cb").id)
    }

    func testServerIdentityHashesCanonicalAddressAndPreservesServerPaths() {
        let identity = FavoriteControl.serverID(for: "  HTTPS://EXAMPLE.COM:443/home/// \n")
        XCTAssertEqual(identity, FavoriteControl.serverID(for: "https://example.com/home"))
        XCTAssertEqual(FavoriteControl.serverID(for: "http://example.com:80/"),
                       FavoriteControl.serverID(for: "http://EXAMPLE.COM"))
        for other in ["https://example.com/other", "http://example.com/home", "https://example.com:8123/home"] {
            XCTAssertNotEqual(identity, FavoriteControl.serverID(for: other))
        }
        XCTAssertEqual(FavoriteControl.serverID(for: "abc"),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(identity.count, 64)
        XCTAssertTrue(identity.allSatisfy { "0123456789abcdef".contains($0) })
    }

    func testSnapshotRoundTripContainsNoAddressOrToken() throws {
        let address = "https://user:secret-token@private.example:8123/home?token=secret-token#secret-token"
        let serverID = FavoriteControl.serverID(for: address)
        XCTAssertEqual(serverID, FavoriteControl.serverID(for: "https://private.example:8123/home"))
        let favorite = FavoriteControl(entity: entity("light"), serverID: serverID, room: "Office")
        let snapshot = FavoriteControlSnapshot(serverID: serverID, favorites: [favorite], connected: true,
                                               updatedAt: Date(timeIntervalSince1970: 123))
        let data = try JSONEncoder().encode(snapshot)
        let encoded = String(decoding: data, as: UTF8.self)
        for secret in [address, "private.example", "secret-token", "https", "token"] {
            XCTAssertFalse(encoded.contains(secret), secret)
        }
        XCTAssertEqual(try JSONDecoder().decode(FavoriteControlSnapshot.self, from: data), snapshot)
        XCTAssertEqual(favorite.entityID, "light.test")
        XCTAssertEqual(favorite.name, "Living room")
        XCTAssertEqual(favorite.room, "Office")
        XCTAssertEqual(favorite.symbol, "lightbulb.fill")
        XCTAssertFalse(favorite.isOn)
        XCTAssertTrue(favorite.available)
    }

    func testToggleRequiresBothPowerCapabilitiesRegardlessOfCurrentState() {
        let cases: [(String, Int, [String], FavoriteControlKind)] = [
            ("light", 0, [], .toggle), ("switch", 0, [], .toggle),
            ("fan", 0, [], .open), ("fan", 16, [], .open), ("fan", 32, [], .open),
            ("fan", 128, [], .open), ("fan", 48, [], .toggle),
            ("climate", 0, [], .open), ("climate", 128, [], .open),
            ("climate", 256, [], .open), ("climate", 384, [], .toggle),
            ("climate", 1, ["off", "heat", "cool"], .open),
            ("climate", 256, ["off", "cool"], .toggle),
            ("climate", 256, ["desligado", "cool"], .open)
        ]
        for (domain, features, modes, expected) in cases {
            for state in ["off", "on", "unavailable"] {
                let value = entity(domain, state: state, features: features, modes: modes)
                let favorite = FavoriteControl(entity: value, serverID: "server")
                XCTAssertEqual(favorite.kind, expected, "\(domain) \(features) \(modes) \(state)")
                XCTAssertEqual(favorite.available, value.available)
                XCTAssertEqual(favorite.isOn, value.isOn)
            }
        }
    }

    func testDesiredPowerIsIdempotentAndTargetsTheEntity() {
        for (domain, features) in [("light", 0), ("switch", 0), ("fan", 48), ("climate", 384)] {
            for desired in [false, true] {
                let current = entity(domain, state: desired ? "off" : "on", features: features)
                let call = ServiceCall.setPower(current, isOn: desired)
                XCTAssertEqual(call, ServiceCall(current, desired ? "turn_on" : "turn_off"))
                XCTAssertEqual(call?.payload["target"]?["entity_id"], .string(current.entityID))
                var reached = current
                reached.state = desired ? "on" : "off"
                XCTAssertNil(ServiceCall.setPower(reached, isOn: desired))
            }
        }
    }

    func testDesiredPowerValidatesEachDirectionAndNeverGuessesClimateMode() {
        for (domain, onFlag, offFlag) in [("fan", 16, 32), ("climate", 256, 128)] {
            XCTAssertNil(ServiceCall.setPower(entity(domain, features: offFlag), isOn: true))
            XCTAssertNil(ServiceCall.setPower(entity(domain, state: "on", features: onFlag), isOn: false))
            XCTAssertEqual(ServiceCall.setPower(entity(domain, features: onFlag), isOn: true)?.service, "turn_on")
            XCTAssertEqual(ServiceCall.setPower(entity(domain, state: "on", features: offFlag), isOn: false)?.service, "turn_off")
        }
        XCTAssertNil(ServiceCall.setPower(entity("fan", features: 128), isOn: true))
        XCTAssertNil(ServiceCall.setPower(entity("fan", state: "on", features: 128), isOn: false))
        let climate = entity("climate", state: "cool", modes: ["off", "heat", "cool"])
        XCTAssertEqual(ServiceCall.setPower(climate, isOn: false),
                       ServiceCall(climate, "set_hvac_mode", data: ["hvac_mode": .string("off")]))
        XCTAssertNil(ServiceCall.setPower(entity("climate", modes: ["off", "heat", "cool"]), isOn: true))
        XCTAssertNil(ServiceCall.setPower(entity("climate", state: "cool", modes: ["desligado"]), isOn: false))
        let native = entity("climate", state: "heat", features: 384, modes: ["off"])
        XCTAssertEqual(ServiceCall.setPower(native, isOn: false), ServiceCall(native, "turn_off"))
    }

    func testUnavailableEntitiesNeverProducePowerCalls() {
        for domain in ["light", "switch", "fan", "climate"] {
            for state in ["unavailable", "unknown"] {
                let value = entity(domain, state: state, features: 432, modes: ["off"])
                XCTAssertNil(ServiceCall.setPower(value, isOn: true))
                XCTAssertNil(ServiceCall.setPower(value, isOn: false))
            }
        }
    }

    func testScenesAndOpenControlsNeverProducePowerCalls() {
        for domain in ["scene", "sensor", "binary_sensor", "cover", "lock", "button", "custom"] {
            for state in ["off", "on"] {
                let value = entity(domain, state: state, features: 432, modes: ["off"])
                let favorite = FavoriteControl(entity: value, serverID: "server")
                XCTAssertEqual(favorite.kind, domain == "scene" ? .scene : .open)
                XCTAssertFalse(favorite.symbol.isEmpty)
                XCTAssertNil(ServiceCall.setPower(value, isOn: true))
                XCTAssertNil(ServiceCall.setPower(value, isOn: false))
            }
        }
        XCTAssertEqual(FavoriteControlKind.toggle.rawValue, "toggle")
        XCTAssertEqual(FavoriteControlKind.scene.rawValue, "scene")
        XCTAssertEqual(FavoriteControlKind.open.rawValue, "open")
    }
}
