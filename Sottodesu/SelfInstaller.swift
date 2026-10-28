import AppKit

/// Finishes the installation when Sottodesu is opened straight from the downloaded disk image:
/// it copies itself to Applications, reopens from there, then ejects the image and moves the
/// downloaded `.dmg` to the Trash. Nothing is left behind.
enum SelfInstaller {
    struct DiskImage: Equatable {
        let imagePath: String
        let mountPoint: String
    }

    /// Finds the mounted disk image that contains `path`, given the plist printed by `hdiutil info -plist`.
    static func diskImage(containing path: String, hdiutilInfo plist: Data) -> DiskImage? {
        guard let root = try? PropertyListSerialization.propertyList(from: plist, format: nil) as? [String: Any],
              let images = root["images"] as? [[String: Any]] else { return nil }
        for image in images {
            guard let imagePath = image["image-path"] as? String,
                  let entities = image["system-entities"] as? [[String: Any]] else { continue }
            for entity in entities {
                guard let mount = entity["mount-point"] as? String else { continue }
                if path == mount || path.hasPrefix(mount + "/") {
                    return DiskImage(imagePath: imagePath, mountPoint: mount)
                }
            }
        }
        return nil
    }

    private static func hdiutilInfo() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["info", "-plist"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }

    /// Shows the offer only when the app is running from a mounted disk image.
    @MainActor
    static func offerIfNeeded() {
        guard !DemoMode.isActive else { return }
        let bundle = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard bundle.path.hasPrefix("/Volumes/"),
              let data = hdiutilInfo(),
              let image = diskImage(containing: bundle.path, hdiutilInfo: data) else { return }

        let alert = NSAlert()
        alert.messageText = String(localized: "Move Sottodesu to Applications?")
        alert.informativeText = String(localized: "Sottodesu will copy itself to your Applications folder and reopen from there. Then it ejects the installer and moves the downloaded disk image to the Trash.")
        alert.addButton(withTitle: String(localized: "Move to Applications"))
        alert.addButton(withTitle: String(localized: "Not Now"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        install(from: bundle, image: image)
    }

    @MainActor
    private static func install(from source: URL, image: DiskImage) {
        let fm = FileManager.default
        let destination = URL(fileURLWithPath: "/Applications/Sottodesu.app")
        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.trashItem(at: destination, resultingItemURL: nil)
            }
            try fm.copyItem(at: source, to: destination)
        } catch {
            let failure = NSAlert()
            failure.alertStyle = .warning
            failure.messageText = String(localized: "Sottodesu couldn’t be copied to Applications.")
            failure.informativeText = String(localized: "You can drag it onto the Applications folder yourself.")
            failure.runModal()
            return
        }

        // Tidy up: the copy shouldn't carry the download's quarantine flag twice, and the
        // installer goes to the Trash. Both are best effort.
        run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", destination.path])
        try? fm.trashItem(at: URL(fileURLWithPath: image.imagePath), resultingItemURL: nil)

        // The image can only be ejected once this copy of the app has quit.
        let eject = Process()
        eject.executableURL = URL(fileURLWithPath: "/bin/sh")
        eject.arguments = ["-c", "sleep 2; /usr/bin/hdiutil detach \"$0\" -force >/dev/null 2>&1", image.mountPoint]
        try? eject.run()

        NSWorkspace.shared.openApplication(at: destination, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private static func run(_ tool: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
