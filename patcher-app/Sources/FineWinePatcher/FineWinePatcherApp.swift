import SwiftUI

@main
struct FineWinePatcherApp: App {
    init() {
        UsageTelemetry.recordAppLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
