import Foundation

/// User-confirmed, per-patch anonymous usage reporting.
///
/// Nothing is queued or sent automatically: after a patch run finishes the app shows a dialog
/// with the exact payload, and only the user's explicit "Send Statistics" action posts it.
enum UsageTelemetry {
    private static let endpoint = URL(string: "https://endfield-fine-wine.lovable.app/api/statistics")!

    /// Only a completed patch run can be reported.
    static let allowedEvents: Set<String> = ["patch_succeeded", "patch_failed"]

    /// Metadata is an allowlist, not a free-form dictionary: a future call site must not be able
    /// to leak a path, bottle name or identifier by adding a new key.
    static let allowedMetadataKeys: Set<String> = [
        "gptk", "duration_seconds", "failed_step",
    ]

    private struct Event: Encodable {
        let app = "endfield-finewine-patcher"
        let event: String
        let count = 1
        let appVersion: String
        let osMajor: Int
        let metadata: [String: String]
    }

    /// A local, unsent report for one patch run. Showing it never sends anything.
    struct Prompt: Identifiable {
        let id = UUID()
        let event: String
        let metadata: [String: String]

        var isSuccess: Bool { event == "patch_succeeded" }

        /// Pretty-printed JSON exactly matching what `send(_:)` would post.
        var json: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(UsageTelemetry.makeEvent(event, metadata: metadata)) else {
                return "{}"
            }
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    static func makePatchPrompt(succeeded: Bool, gptk: Bool, failedStep: Int?, durationSeconds: Int) -> Prompt {
        var metadata = [
            "gptk": gptk ? "true" : "false",
            "duration_seconds": String(durationSeconds),
        ]
        if let failedStep { metadata["failed_step"] = String(failedStep) }
        return Prompt(
            event: succeeded ? "patch_succeeded" : "patch_failed",
            metadata: safeMetadata(metadata)
        )
    }

    /// Drops any metadata key that was not explicitly approved for collection.
    static func safeMetadata(_ metadata: [String: String]) -> [String: String] {
        metadata.filter { allowedMetadataKeys.contains($0.key) }
    }

    /// Called only from the user's "Send Statistics" button in the patch-run prompt.
    static func send(_ prompt: Prompt) {
        guard allowedEvents.contains(prompt.event) else { return }
        // Re-sanitise here as well, so a hand-built Prompt cannot bypass the allowlist.
        let event = makeEvent(prompt.event, metadata: prompt.metadata)
        Task {
            await post(event)
        }
    }

    private static func makeEvent(_ name: String, metadata: [String: String]) -> Event {
        Event(
            event: name,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            metadata: safeMetadata(metadata)
        )
    }

    private static func post(_ event: Event) async {
        guard let body = try? JSONEncoder().encode(event) else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 4
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }
}
