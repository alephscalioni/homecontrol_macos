import XCTest
@testable import HomeCore

final class UpdateConfigurationTests: XCTestCase {
    private let publicKey = Data(repeating: 7, count: 32).base64EncodedString()
    func testUnconfiguredBuildDoesNotStartAnUpdater() throws {
        XCTAssertNil(try UpdateConfiguration.read(info: [:]))
    }
    func testReleaseAcceptsHTTPSFeedAndPublicKey() throws {
        let config = try XCTUnwrap(UpdateConfiguration.read(info: ["SUFeedURL": "https://updates.example.org/appcast.xml", "SUPublicEDKey": publicKey]))
        XCTAssertEqual(config.feedURL.scheme, "https")
        XCTAssertEqual(config.publicEDKey, publicKey)
    }
    func testRejectsInsecureOrCredentialBearingFeedURLs() {
        for feed in ["http://updates.example.org/appcast.xml", "file:///tmp/appcast.xml", "https://user:password@updates.example.org/feed", "https://updates.example.org/feed?token=test", "https://updates.example.org/feed#fragment", "https:///feed"] {
            XCTAssertThrowsError(try UpdateConfiguration.read(info: ["SUFeedURL": feed, "SUPublicEDKey": publicKey]), feed)
        }
    }
    func testRejectsPartialConfigurationAndInvalidKeys() {
        XCTAssertThrowsError(try UpdateConfiguration.read(info: ["SUFeedURL": "https://updates.example.org/feed"]))
        XCTAssertThrowsError(try UpdateConfiguration.read(info: ["SUPublicEDKey": publicKey]))
        for key in ["", "not-base64", Data(repeating: 1, count: 31).base64EncodedString(), Data(repeating: 1, count: 64).base64EncodedString()] {
            XCTAssertThrowsError(try UpdateConfiguration.read(info: ["SUFeedURL": "https://updates.example.org/feed", "SUPublicEDKey": key]))
        }
    }
}
