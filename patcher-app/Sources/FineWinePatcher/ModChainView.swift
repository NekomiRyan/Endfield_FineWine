import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Bottle-side EFMI mod-chain tooling, opened from the app's Tools menu rather than being mixed
/// into the main patch flow.
struct ModChainView: View {
    @EnvironmentObject private var engine: PatcherEngine

    @State private var bottles: [BottleInfo] = []
    @State private var chainBottle: BottleInfo?
    @State private var chainApp: URL?
    @State private var chainImporterOverride: URL?
    @State private var chainPlan: ChainPlan?
    @State private var chainSetupError: String?
    @State private var chainState: ChainState?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mod chain (EFMI)")
                    .font(.title2.weight(.semibold))
                Text("Tools for pointing EFMI's d3d11.dll at the patched app's D3D11→Metal backend.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            modChainBox

            if !engine.modSteps.isEmpty { stepsList(engine.modSteps) }
            if let error = engine.modError { errorBox(error) }
        }
        .padding(20)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { refreshChain() }
        .onChange(of: engine.patchedApp) { _ in refreshChain() }
    }

    private var modChainBox: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label("EFMI chain", systemImage: "puzzlepiece.extension")
                        .font(.callout.weight(.medium))
                    Spacer()
                    if let state = chainState {
                        Label("applied · \(state.backend)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Text("Chains EFMI's d3d11.dll onto this app's D3D11→Metal backend (proxy_d3d11), so mods hand off to Metal instead of Wine's wined3d. Requires XXMI Launcher + EFMI installed in the bottle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if bottles.isEmpty {
                    Text("No CrossOver bottles found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Bottle:", selection: $chainBottle) {
                        ForEach(bottles) { bottle in
                            Text(bottle.name).tag(Optional(bottle))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: chainBottle) { _ in refreshChain() }

                    if let bottle = chainBottle {
                        Text("Backend: \(bottle.backend?.displayName ?? "wined3d (none)") — \(bottle.backend != nil ? "chain possible" : "the default chain is already correct here, nothing to do")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let plan = chainPlan {
                    Text("target: \(plan.target)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    HStack {
                        Button(engine.modIsRunning ? "Applying…" : (chainState == nil ? "Apply chain" : "Re-apply")) {
                            engine.applyModChain(plan: plan)
                        }
                        .disabled(engine.modIsRunning || engine.isRunning)
                        Button("Revert") {
                            engine.revertModChain(importerDir: plan.importerDir)
                        }
                        .disabled(engine.modIsRunning || engine.isRunning || chainState == nil)
                    }
                }

                HStack {
                    Button("Choose EFMI folder…", action: chooseImporter)
                        .disabled(engine.modIsRunning)
                    Button("Choose patched app…", action: choosePatchedApp)
                        .disabled(engine.modIsRunning)
                }

                if let error = chainSetupError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
    }

    private func stepsList(_ steps: [PatcherEngine.Step]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(steps) { step in
                HStack(spacing: 8) {
                    stepIcon(step.status)
                        .frame(width: 16, height: 16)
                    Text(step.label)
                        .font(.callout)
                        .foregroundStyle(step.status == .pending ? .secondary : .primary)
                }
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func stepIcon(_ status: PatcherEngine.Step.Status) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle").foregroundStyle(.tertiary)
        case .running:
            ProgressView().controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private func errorBox(_ message: String) -> some View {
        Label(message, systemImage: "xmark.octagon.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refreshChain() {
        chainSetupError = nil
        chainPlan = nil
        chainState = nil

        bottles = BottleInfo.detectAll()
        if chainBottle == nil || !bottles.contains(where: { $0.id == chainBottle?.id }) {
            chainBottle = bottles.first { $0.name == "Arknights Endfield" } ?? bottles.first
        }
        let app = chainApp ?? engine.patchedApp ?? ModChain.defaultPatchedApp()
        guard let app, ModChain.isPatchedCrossOver(app) else {
            chainSetupError = "No patched CrossOver app yet — create one in the main window (or use Choose patched app… to point at an existing one)."
            return
        }
        guard let bottle = chainBottle else {
            chainSetupError = "No CrossOver bottle found."
            return
        }
        guard let backend = bottle.backend else { return }   // wined3d: nothing to chain, by design

        do {
            guard let importer = ModChain.locateImporter(bottle: bottle.url, override: chainImporterOverride) else {
                chainSetupError = "Could not find an EFMI folder in this bottle (looked in XXMI Launcher's config and its default location). Install EFMI first, or use Choose EFMI folder…."
                return
            }
            chainPlan = try ModChain.plan(patchedApp: app, bottle: bottle.url,
                                          backend: backend, importerDir: importer)
            chainState = ModChain.readState(importerDir: importer)
        } catch {
            chainSetupError = error.localizedDescription
        }
    }

    private func choosePatchedApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose the patched CrossOver app"
        panel.message = "The app the mod chain should point at (e.g. CrossOver_Endfield_Patch.app)."
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url, ModChain.isPatchedCrossOver(url) {
            chainApp = url
            refreshChain()
        }
    }

    private func chooseImporter() {
        let panel = NSOpenPanel()
        panel.title = "Choose the EFMI folder"
        panel.message = "The folder that contains EFMI's d3dx.ini (e.g. …\\XXMI Launcher\\EFMI)."
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = chainBottle.map { $0.url.appendingPathComponent("drive_c") }
        if panel.runModal() == .OK, let url = panel.url {
            chainImporterOverride = url
            refreshChain()
        }
    }
}
