import XCTest
@testable import FineWinePatcher

final class UsageTelemetryTests: XCTestCase {

    func testOnlyAllowlistedMetadataCanBeSent() {
        let safe = UsageTelemetry.safeMetadata([
            "gptk": "true",
            "duration_seconds": "42",
            "failed_step": "3",
            "path": "/Users/example/Bottles/private",
            "bottle": "Arknights Endfield",
            "token": "secret",
        ])
        XCTAssertEqual(safe, [
            "gptk": "true",
            "duration_seconds": "42",
            "failed_step": "3",
        ])
    }

    func testFailedPatchPromptContainsOnlyTheApprovedSchema() throws {
        let prompt = UsageTelemetry.makePatchPrompt(
            succeeded: false, gptk: true, failedStep: 3, durationSeconds: 42
        )
        XCTAssertEqual(prompt.event, "patch_failed")
        XCTAssertFalse(prompt.isSuccess)

        let object = try jsonObject(prompt)
        XCTAssertEqual(
            Set(object.keys),
            ["app", "event", "count", "appVersion", "osMajor", "metadata"]
        )
        XCTAssertEqual(object["event"] as? String, "patch_failed")
        let metadata = try XCTUnwrap(object["metadata"] as? [String: String])
        XCTAssertEqual(metadata, [
            "gptk": "true",
            "duration_seconds": "42",
            "failed_step": "3",
        ])
    }

    func testSuccessfulPatchPromptHasNoFailedStep() throws {
        let prompt = UsageTelemetry.makePatchPrompt(
            succeeded: true, gptk: false, failedStep: nil, durationSeconds: 12
        )
        XCTAssertEqual(prompt.event, "patch_succeeded")
        XCTAssertTrue(prompt.isSuccess)

        let metadata = try XCTUnwrap(try jsonObject(prompt)["metadata"] as? [String: String])
        XCTAssertEqual(metadata, ["gptk": "false", "duration_seconds": "12"])
        XCTAssertNil(metadata["failed_step"])
    }

    private func jsonObject(_ prompt: UsageTelemetry.Prompt) throws -> [String: Any] {
        let data = try XCTUnwrap(prompt.json.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
