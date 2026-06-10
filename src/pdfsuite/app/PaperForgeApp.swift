import SwiftUI

@main
struct PaperForgeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 540)
        }
        .defaultSize(width: 960, height: 660)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
