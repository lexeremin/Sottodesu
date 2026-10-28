import AppKit

/// macOS has no uninstall hook, so dragging an app to the Trash can't clean up after it.
/// This command does the whole job: it deletes Sottodesu's data, then moves the app itself to the Trash.
enum Uninstaller {
    @MainActor
    static func confirmAndRun() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Uninstall Sottodesu?"
        alert.informativeText = "This deletes Sottodesu’s history and moves the app to the Trash. Files that are already sorted stay where they are, and you won’t be able to undo past sorts."
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let fm = FileManager.default
        for url in [AppPaths.supportDirectory] + AppPaths.systemGeneratedLeftovers {
            try? fm.removeItem(at: url)
        }

        NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, error in
            DispatchQueue.main.async {
                if error != nil {
                    let failure = NSAlert()
                    failure.messageText = "Data removed, but the app couldn’t be moved to the Trash."
                    failure.informativeText = "You can drag Sottodesu to the Trash yourself."
                    failure.runModal()
                }
                NSApp.terminate(nil)
            }
        }
    }
}
