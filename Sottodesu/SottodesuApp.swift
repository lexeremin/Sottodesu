import SwiftUI

@main
struct SottodesuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = DemoMode.isActive ? (DemoMode.makeModel() ?? AppModel()) : AppModel()

    var body: some Scene {
        Window("Sottodesu", id: "main") {
            ContentView()
                .environment(model)
        }
        .defaultSize(width: 860, height: 660)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        // Don't write "saved application state" files to ~/Library.
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()
                Button("Uninstall Sottodesu…") { Uninstaller.confirmAndRun() }
            }
            CommandMenu("Go") {
                Button("Sort") { model.tab = .sort }
                    .keyboardShortcut("1")
                Button("Report") { model.tab = .report }
                    .keyboardShortcut("2")
                Button("Largest Files") { model.tab = .largest }
                    .keyboardShortcut("3")
                Divider()
                Button("Rescan") { model.rescan() }
                    .keyboardShortcut("r")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
