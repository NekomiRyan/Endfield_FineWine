import Foundation

/// Opt-in, best-effort anonymous usage reporting for the patcher.
///
/// Nothing is sent unless the user explicitly enables the statistics toggle. Events contain
/// only the app version, macOS major version and the small event-specific metadata documented
/// in `patcher-app/README.md`; no paths, bottle names, game/account data or persistent
/// identifiers are collected. The server may still see network metadata that comes with any
/// ordinary HTTPS request, such as the source IP address.
enum UsageTelemetry {
    private static let enabledKey = "finewine.statistics.enabled"
    private static let installedKey = "finewine.statistics.installed"
    private static let endpoint = URL(string: "https://endfield-fine-wine.lovable.app/api/statistics")!

    /// Only known, non-identifying event names may leave the machine.
    private static let allowedEvents: Set<String> = [
        "app_installed", "app_launched",
        "patch_started", "patch_succeeded", "patch_failed",
        "mod_chain_apply_started", "mod_chain_apply_succeeded", "mod_chain_apply_failed",
        "mod_chain_revert_started", "mod_chain_revert_succeeded", "mod_chain_revert_failed",
    ]

    /// Metadata is an allowlist, not a free-form dictionary: a future call site must not be able
    /// to leak a path, bottle name or identifier by adding a new key.
    static let allowedMetadataKeys: Set<String> = [
        "backend", "gptk", "duration_seconds", "failed_step",
    ]

    private struct Event: Encodable {
        let app = "endfield-finewine-patcher"
        let event: String
        let count = 1
        let appVersion: String
        let osMajor: Int
        let metadata: [String: String]
    }

    /// A read-only example of one outbound request, shown by the in-app preview.
    struct PreviewSample: Identifiable {
        let id: String
        let title: String
        let json: String
    }

    /// Opt-in: absent means disabled. Do not change this to `true` — first-run installs and
    /// launches must never be reported before the user has enabled statistics.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    static func recordAppLaunch() {
        // Marking the install before checking consent would suppress `app_installed` forever
        // for users who enable statistics after their first launch.
        guard isEnabled else { return }
        if !UserDefaults.standard.bool(forKey: installedKey) {
            UserDefaults.standard.set(true, forKey: installedKey)
            record("app_installed")
        }
        record("app_launched")
    }

    static func record(_ event: String, metadata: [String: String] = [:]) {
        guard isEnabled, allowedEvents.contains(event) else { return }
        Task {
            await send(makeEvent(event, metadata: metadata))
        }
    }

    /// Drops any metadata key that was not explicitly approved for collection.
    static func safeMetadata(_ metadata: [String: String]) -> [String: String] {
        metadata.filter { allowedMetadataKeys.contains($0.key) }
    }

    /// Exact request examples for the in-app preview. Building these examples never sends data.
    static func previewSamples() -> [PreviewSample] {
        [
            PreviewSample(
                id: "patch_failed",
                title: "A failed patch attempt",
                json: previewJSON(event: "patch_failed", metadata: [
                    "gptk": "true", "duration_seconds": "42", "failed_step": "3",
                ])
            ),
            PreviewSample(
                id: "mod_chain_apply_started",
                title: "Starting an EFMI mod-chain apply",
                json: previewJSON(event: "mod_chain_apply_started", metadata: ["backend": "dxmt"])
            ),
            PreviewSample(
                id: "app_launched",
                title: "A normal app launch",
                json: previewJSON(event: "app_launched")
            ),
        ]
    }

    private static func makeEvent(_ name: String, metadata: [String: String]) -> Event {
        Event(
            event: name,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            metadata: safeMetadata(metadata)
        )
    }

    private static func previewJSON(event name: String, metadata: [String: String] = [:]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(makeEvent(name, metadata: metadata)) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func send(_ event: Event) async {
        guard let body = try? JSONEncoder().encode(event) else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 4
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        _ = try? await URLSession.shared.data(for: request)
    }
}
