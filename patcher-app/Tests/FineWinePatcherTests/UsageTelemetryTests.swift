import XCTest
@testable import FineWinePatcher

final class UsageTelemetryTests: XCTestCase {

    func testTelemetryIsOptedOutByDefault() {
        let defaults = UserDefaults.standard
        let enabledKey = "finewine.statistics.enabled"
        let installedKey = "finewine.statistics.installed"
        let oldEnabled = defaults.object(forKey: enabledKey)
        let oldInstalled = defaults.object(forKey: installedKey)
        defer {
            if let oldEnabled { defaults.set(oldEnabled, forKey: enabledKey) }
            else { defaults.removeObject(forKey: enabledKey) }
            if let oldInstalled { defaults.set(oldInstalled, forKey: installedKey) }
            else { defaults.removeObject(forKey: installedKey) }
        }

        defaults.removeObject(forKey: enabledKey)
        defaults.removeObject(forKey: installedKey)

        XCTAssertFalse(UsageTelemetry.isEnabled)
        UsageTelemetry.recordAppLaunch()
        XCTAssertFalse(defaults.bool(forKey: installedKey),
                       "the first-launch install event must wait for explicit consent")
    }

    func testOnlyAllowlistedMetadataCanBeSent() {
        let safe = UsageTelemetry.safeMetadata([
            "backend": "dxmt",
            "gptk": "true",
            "path": "/Users/example/Bottles/private",
            "bottle": "Arknights Endfield",
            "token": "secret",
        ])
        XCTAssertEqual(safe, ["backend": "dxmt", "gptk": "true"])
    }

    func testPreviewSamplesContainOnlyTheApprovedSchema() throws {
        let samples = UsageTelemetry.previewSamples()
        XCTAssertFalse(samples.isEmpty)
        for sample in samples {
            let data = try XCTUnwrap(sample.json.data(using: .utf8))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: data) as? [String: Any]
            )
            XCTAssertEqual(
                Set(object.keys),
                ["app", "event", "count", "appVersion", "osMajor", "metadata"]
            )
            let metadata = try XCTUnwrap(object["metadata"] as? [String: String])
            XCTAssertTrue(Set(metadata.keys).isSubset(of: UsageTelemetry.allowedMetadataKeys))
        }
    }
}
