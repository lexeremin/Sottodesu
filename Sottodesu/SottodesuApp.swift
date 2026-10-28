import SwiftUI

@main
struct SottodesuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Sottodesu", id: "main") {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 480, height: 560)
        .windowResizability(.contentMinSize)
        // Don't write "saved application state" files to ~/Library.
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Uninstall Sottodesu…") { Uninstaller.confirmAndRun() }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
