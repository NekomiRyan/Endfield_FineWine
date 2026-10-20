import SwiftUI

/// Read-only preview of the telemetry payload. Opening this view never sends anything, and it is
/// available whether reporting is currently enabled or disabled.
struct TelemetryPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    private let samples = UsageTelemetry.previewSamples()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What would be sent")
                .font(.title3.weight(.semibold))
            Text("Preview only — this window does not send anything. Each event is a JSON POST to the statistics endpoint. The envelope is fixed; the event name and metadata vary with what you do in the patcher.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(samples) { sample in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(sample.title)
                                .font(.caption.weight(.semibold))
                            Text(sample.json)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    Text("No file paths, bottle names, game or account data, usernames, hardware serials, or persistent identifiers are included. The statistics server can still see ordinary network metadata such as your IP address, as with any HTTPS request.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Text("The preview is local and sends no data.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 600, height: 540)
    }
}
