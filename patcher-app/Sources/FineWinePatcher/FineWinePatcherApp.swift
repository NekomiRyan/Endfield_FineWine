import SwiftUI

@main
struct FineWinePatcherApp: App {
    @StateObject private var engine = PatcherEngine()

    init() {
        UsageTelemetry.recordAppLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            AppToolsMenu()
        }

        Window("Mod Chain (EFMI)", id: "mod-chain") {
            ModChainView()
                .environmentObject(engine)
        }
        .windowResizability(.contentSize)
    }
}

private struct AppToolsMenu: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Tools") {
            Button("Mod Chain (EFMI)…") {
                openWindow(id: "mod-chain")
            }
        }
    }
}
