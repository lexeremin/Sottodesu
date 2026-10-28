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
                Button("Schedule") { model.tab = .schedule }
                    .keyboardShortcut("4")
                Divider()
                Button("Rescan") { model.rescan() }
                    .keyboardShortcut("r")
            }
        }

        // Optional: a small icon in the menu bar (switched on in the Schedule tab).
        MenuBarExtra("Sottodesu", systemImage: "tray.full",
                     isInserted: Binding(get: { model.showsMenuBarIcon }, set: { model.setMenuBar($0) })) {
            MenuBarContent()
                .environment(model)
        }
    }
}

/// What the menu bar icon shows.
private struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let last = model.runs.first {
            Text("Last sort: \(last.startedAt.formatted(date: .abbreviated, time: .shortened))")
        } else {
            Text("No sorts yet")
        }
        Divider()
        Button("Sort \(model.locationName) Now") { model.sort() }
            .disabled(!model.canSort)
        Button("Open Sottodesu") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        if !model.schedules.isEmpty {
            Toggle("Pause schedules", isOn: Binding(get: { model.schedulesPaused },
                                                    set: { model.setSchedulesPaused($0) }))
        }
        Divider()
        Button("Quit Sottodesu") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in SelfInstaller.offerIfNeeded() }

        guard MenuBarPreference.isEnabled, Self.launchedAsLoginItem else { return }
        // Started at login: stay quietly in the menu bar instead of opening the window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.windows.forEach { $0.close() }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// True when macOS opened the app because it is an "open at login" item.
    private static var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        let openApplication = AEEventID(0x6F617070)   // 'oapp'
        let propData = AEKeyword(0x70726474)          // 'prdt'
        let loginItem = AEKeyword(0x6C676974)         // 'lgit'
        return event.eventID == openApplication
            && event.paramDescriptor(forKeyword: propData)?.enumCodeValue == loginItem
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // With the menu bar icon on, closing the window leaves Sottodesu in the menu bar (and out of the Dock).
        if MenuBarPreference.isEnabled {
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        return true
    }
}
