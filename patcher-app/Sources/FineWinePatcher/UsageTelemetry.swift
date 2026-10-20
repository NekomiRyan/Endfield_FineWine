import Foundation

/// Best-effort, anonymous usage reporting for the patcher.
///
/// Events intentionally contain no paths, account data, IP-address fields, or identifiers.
/// The server may still see the network metadata that comes with any ordinary HTTPS request.
enum UsageTelemetry {
    private static let enabledKey = "finewine.statistics.enabled"
    private static let installedKey = "finewine.statistics.installed"
    private static let endpoint = URL(string: "https://endfield-fine-wine.lovable.app/api/statistics")!

    private struct Event: Encodable {
        let app = "endfield-finewine-patcher"
        let event: String
        let count = 1
        let appVersion: String
        let osMajor: Int
        let metadata: [String: String]
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
    }

    static func recordAppLaunch() {
        if !UserDefaults.standard.bool(forKey: installedKey) {
            UserDefaults.standard.set(true, forKey: installedKey)
            record("app_installed")
        }
        record("app_launched")
    }

    static func record(_ event: String, metadata: [String: String] = [:]) {
        guard isEnabled else { return }
        Task {
            await send(Event(
                event: event,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                metadata: metadata
            ))
        }
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
