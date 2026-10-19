import Foundation
import XCTest
@testable import HomeCore

final class CameraMediaTests: XCTestCase {
    func testOnlyCameraIDsCanBuildAuthenticatedRequestsAndBasePathIsPreserved() throws {
        let request = try CameraMedia.request(server: "https://example.invalid/ha/", token: "fixture-secret", entityID: "camera.entrance")
        XCTAssertEqual(request.url?.path, "/ha/api/camera_proxy/camera.entrance")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-secret")
        XCTAssertFalse(request.url!.absoluteString.contains("fixture-secret"))
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        for id in ["light.test", "camera.x/../../", "camera.x?token=oops", "camera.x#fragment", "camera.", "camera.x%2fy"] {
            XCTAssertThrowsError(try CameraMedia.request(server: "https://example.invalid", token: "fixture", entityID: id))
        }
        XCTAssertThrowsError(try CameraMedia.request(server: "https://user:password@example.invalid", token: "fixture", entityID: "camera.test"))
        XCTAssertThrowsError(try CameraMedia.request(server: "https://example.invalid", token: "x\r\ny", entityID: "camera.test"))
    }

    func testCameraCatalogNeverSharesPictureURLOrTokensAndHasNoPowerAction() throws {
        let entity = HAEntity("camera.test", state: "idle", attributes: ["friendly_name": .string("Fixture camera"), "entity_picture": .string("/api/camera_proxy/camera.test?token=private-camera-token"), "access_token": .string("private-access-token")])
        XCTAssertTrue(entity.isSupported)
        let control = FavoriteControl(entity: entity, serverID: "fixture")
        XCTAssertEqual(control.kind, .open)
        XCTAssertTrue(control.isCamera)
        XCTAssertTrue(HomeWidgetSelection.supports(control))
        XCTAssertTrue(HomeWidgetSelection.matches(control, query: "câmeras"))
        XCTAssertTrue(HomeWidgetSelection.matches(control, query: "cameras"))
        XCTAssertNil(ServiceCall.power(entity))
        XCTAssertNil(ServiceCall.setPower(entity, isOn: false))
        let serialized = String(decoding: try JSONEncoder().encode(control), as: UTF8.self)
        XCTAssertFalse(serialized.contains("token"))
        XCTAssertFalse(serialized.contains("camera_proxy"))
    }

    func testAddingCameraKeepsSharedCatalogReadableByOlderWidgetBuilds() throws {
        enum LegacyKind: String, Decodable { case toggle, scene, open }
        struct LegacyControl: Decodable { let entityID: String; let kind: LegacyKind }
        struct LegacySnapshot: Decodable { let controls: [LegacyControl] }
        let camera = FavoriteControl(entity: HAEntity("camera.test", state: "idle", attributes: [:]), serverID: "fixture")
        let light = FavoriteControl(entity: HAEntity("light.test", state: "on", attributes: [:]), serverID: "fixture")
        let snapshot = FavoriteControlSnapshot(serverID: "fixture", favorites: [], connected: true, controls: [camera, light])
        let data = try JSONEncoder().encode(snapshot)
        let legacy = try JSONDecoder().decode(LegacySnapshot.self, from: data)
        XCTAssertEqual(legacy.controls.map(\.entityID), ["camera.test", "light.test"])
        XCTAssertEqual(legacy.controls.map(\.kind), [.open, .toggle])
        let current = try JSONDecoder().decode(FavoriteControlSnapshot.self, from: data)
        XCTAssertTrue(HomeWidgetSelection.options(in: current).first?.isCamera == true)
    }

    func testMultipartFramesAreReassembledAcrossEveryByteAndRespectLengthInsidePayload() throws {
        let frame = Data("image\r\n--fixture\r\nnot-a-boundary-in-a-length-delimited-frame".utf8)
        var decoder = try CameraMultipartDecoder(boundary: "fixture")
        let message = Data("--fixture\r\nContent-Type: image/jpeg\r\nContent-Length: \(frame.count)\r\n\r\n".utf8) + frame + Data("\r\n".utf8)
        var actual: [Data] = []
        for byte in message + message { actual += try decoder.append(Data([byte])) }
        XCTAssertEqual(actual, [frame, frame])
    }

    func testMultipartWithoutLengthAndHostileBounds() throws {
        var decoder = try CameraMultipartDecoder(boundary: "fixture")
        let actual = try decoder.append(Data("--fixture\r\nContent-Type: image/jpeg\r\n\r\nfirst\r\n--fixture\r\nContent-Type: image/jpeg\r\n\r\nsecond\r\n--fixture--\r\n".utf8))
        XCTAssertEqual(actual, [Data("first".utf8), Data("second".utf8)])
        XCTAssertThrowsError(try CameraMultipartDecoder(boundary: "bad\r\nheader"))
        var large = try CameraMultipartDecoder(boundary: "fixture")
        XCTAssertThrowsError(try large.append(Data("--fixture\r\nContent-Length: 999999999\r\n\r\n".utf8)))
        var endless = try CameraMultipartDecoder(boundary: "fixture")
        XCTAssertThrowsError(try endless.append(Data(repeating: 0, count: CameraMedia.maximumBytes + 65537)))
    }

    func testPrivateCacheIsAccountScopedAtomicBoundedAndPurged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = CameraSnapshotStore(directory: directory)
        let first = CameraSnapshot(data: Data([1, 2, 3]), capturedAt: Date(timeIntervalSince1970: 100))
        try cache.write(first, id: "account-one|camera.test")
        XCTAssertEqual(try cache.read(id: "account-one|camera.test"), first)
        XCTAssertThrowsError(try cache.read(id: "account-two|camera.test"))
        let second = CameraSnapshot(data: Data([4]))
        try cache.write(second, id: "account-one|camera.test")
        XCTAssertEqual(try cache.read(id: "account-one|camera.test"), second)
        let files = try FileManager.default.contentsOfDirectory(at: directory.appendingPathComponent("CameraImages"), includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        XCTAssertFalse(files[0].lastPathComponent.contains("camera"))
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: files[0].path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertThrowsError(try cache.write(CameraSnapshot(data: Data(repeating: 0, count: CameraSnapshotStore.maximumBytes + 1)), id: "large"))
        try cache.retain(only: [])
        XCTAssertThrowsError(try cache.read(id: "account-one|camera.test"))
    }

    private func fixtureRequest(_ name: String = "test", streaming: Bool = false, token: String = "test-camera") throws -> URLRequest {
        guard let server = ProcessInfo.processInfo.environment["HA_TEST_SERVER"] else { throw XCTSkip("Use scripts/test-integration.sh") }
        return try CameraMedia.request(server: server, token: token, entityID: "camera." + name, streaming: streaming)
    }
    func testAuthenticatedSnapshotAndStreamingThroughActualHTTPFixture() async throws {
        let image = try await CameraMedia.image(for: fixtureRequest())
        XCTAssertEqual(Array(image.prefix(4)), [137, 80, 78, 71])
        var frames: [Data] = []
        let stream = CameraMedia.stream(for: try fixtureRequest(streaming: true))
        defer { stream.cancel() }
        for try await frame in stream.frames {
            frames.append(frame)
            if frames.count == 3 { break }
        }
        XCTAssertEqual(frames, [image, image, image])
    }
    func testHTTPAuthenticationRedirectsErrorsAndSizeLimitsFailClosed() async throws {
        let requests = try [fixtureRequest(token: "invalid"), fixtureRequest("redirect"), fixtureRequest("large"), fixtureRequest("failure"), fixtureRequest("html")]
        for request in requests {
            do { _ = try await CameraMedia.image(for: request); XCTFail("Invalid camera response was accepted") }
            catch { XCTAssertTrue(error is CameraMediaError, "Unexpected fixture error: \(error)") }
        }
    }
}
