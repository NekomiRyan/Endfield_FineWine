import SwiftUI

/// Shown once after a patch run finishes. The user sees the exact payload and actively chooses
/// whether this run's anonymous report is sent.
struct PatchTelemetryPromptView: View {
    let prompt: UsageTelemetry.Prompt
    let onDecision: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        prompt.isSuccess
            ? "Send anonymous statistics for this successful patch?"
            : "Send anonymous statistics for this failed patch?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text("""
            This report is optional and is the only thing the patcher would send for this run. \
            It helps us see which macOS and CrossOver versions, graphics backends, and patch \
            steps fail most often, so we can prioritise compatibility and performance fixes. \
            Nothing has been sent yet; it is only sent if you choose Send Statistics.
            """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Preview — exactly what would be sent")
                .font(.caption.weight(.semibold))

            ScrollView {
                Text(prompt.json)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxHeight: 260)

            Text("No file paths, bottle names, game or account data, usernames, hardware serials, or persistent identifiers are included. The statistics server can still see ordinary network metadata such as your IP address, as with any HTTPS request.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Don't Send") {
                    onDecision(false)
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Send Statistics") {
                    onDecision(true)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 620, height: 500)
        .interactiveDismissDisabled(false)
    }
}
