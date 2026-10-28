import AppKit
import CryptoKit
import Foundation
import UserNotifications

/// A version number such as "1.3.0" (a leading "v" is allowed, as in a Git tag).
struct AppVersion: Comparable, Equatable, CustomStringConvertible {
    let parts: [Int]

    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("v") { text.removeFirst() }
        // "1.4.0-beta" is treated as 1.4.0 here; pre-releases are never offered anyway.
        text = String(text.split(separator: "-", maxSplits: 1).first ?? "")
        let numbers = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, !numbers.contains(where: { $0 == nil }) else { return nil }
        parts = numbers.compactMap { $0 }
    }

    var description: String { parts.map(String.init).joined(separator: ".") }

    private static func compare(_ a: AppVersion, _ b: AppVersion) -> Int {
        for index in 0..<max(a.parts.count, b.parts.count) {
            let x = index < a.parts.count ? a.parts[index] : 0
            let y = index < b.parts.count ? b.parts[index] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }

    static func < (a: AppVersion, b: AppVersion) -> Bool { compare(a, b) < 0 }
    static func == (a: AppVersion, b: AppVersion) -> Bool { compare(a, b) == 0 }
}

/// The newest published release, as described by GitHub.
struct ReleaseInfo: Equatable {
    let tag: String
    let version: AppVersion
    let notes: String
    let pageURL: URL
    let dmgURL: URL?
    let checksumURL: URL?

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
        let tag_name: String
        let html_url: String
        let body: String?
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]?
    }

    /// Only downloads from GitHub itself are ever trusted.
    static func isTrusted(_ url: URL) -> Bool {
        guard url.scheme == "https", let host = url.host?.lowercased() else { return false }
        return host == "github.com" || host.hasSuffix(".github.com") || host.hasSuffix(".githubusercontent.com")
    }

    /// Reads the answer of `GET /repos/…/releases/latest`. Drafts and pre-releases are ignored.
    static func parse(_ data: Data) -> ReleaseInfo? {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.draft != true, payload.prerelease != true,
              let version = AppVersion(payload.tag_name),
              let page = URL(string: payload.html_url), isTrusted(page) else { return nil }
        let assets = payload.assets ?? []
        func url(where match: (String) -> Bool) -> URL? {
            assets.first { match($0.name.lowercased()) }
                .flatMap { URL(string: $0.browser_download_url) }
                .flatMap { isTrusted($0) ? $0 : nil }
        }
        return ReleaseInfo(tag: payload.tag_name, version: version, notes: payload.body ?? "", pageURL: page,
                           dmgURL: url { $0.hasSuffix(".dmg") },
                           checksumURL: url { $0.hasSuffix(".sha256") })
    }

    /// The hash in a `.sha256` file ("<64 hex digits>  <file name>").
    static func checksum(fromFile text: String) -> String? {
        guard let first = text.split(whereSeparator: \.isWhitespace).first else { return nil }
        let hash = first.lowercased()
        return hash.count == 64 && hash.allSatisfy(\.isHexDigit) ? hash : nil
    }
}

enum UpdateService {
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/lexeremin/Sottodesu/releases/latest")!

    static var currentVersion: AppVersion? {
        AppVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
    }

    /// An in-memory session, so nothing is cached on disk (no leftover files).
    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    static func fetchLatest() async throws -> ReleaseInfo {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Sottodesu/\(currentVersion?.description ?? "0")", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let release = ReleaseInfo.parse(data) else { throw UpdateFailure.noRelease }
        return release
    }
}

enum UpdateFailure: LocalizedError {
    case noRelease, noInstaller, checksumMismatch, notWritable, damaged

    var errorDescription: String? {
        switch self {
        case .noRelease:
            return String(localized: "No release information was found.")
        case .noInstaller:
            return String(localized: "This release has no installer that can be checked, so it can’t be installed automatically.")
        case .checksumMismatch:
            return String(localized: "The download didn’t match its checksum, so it was thrown away.")
        case .notWritable:
            return String(localized: "Sottodesu can’t replace itself in this folder.")
        case .damaged:
            return String(localized: "The downloaded app isn’t the expected one.")
        }
    }
}

/// A new copy of the app, verified and ready to swap in.
struct StagedUpdate {
    let stagedApp: URL
    let destination: URL
}

enum UpdateInstaller {
    /// Downloads the disk image, checks its SHA-256 against the published checksum, and copies the app
    /// next to the installed one. Nothing is replaced yet.
    static func stage(_ release: ReleaseInfo) async throws -> StagedUpdate {
        guard let dmgURL = release.dmgURL, let checksumURL = release.checksumURL else { throw UpdateFailure.noInstaller }
        let fm = FileManager.default
        let destination = Bundle.main.bundleURL
        let parent = destination.deletingLastPathComponent()
        guard fm.isWritableFile(atPath: parent.path) else { throw UpdateFailure.notWritable }

        let work = fm.temporaryDirectory.appendingPathComponent("sottodesu-update-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let session = UpdateService.session
        let (checksumData, checksumResponse) = try await session.data(from: checksumURL)
        guard (checksumResponse as? HTTPURLResponse)?.statusCode == 200,
              let expected = ReleaseInfo.checksum(fromFile: String(decoding: checksumData, as: UTF8.self)) else {
            throw UpdateFailure.noInstaller
        }

        let (downloaded, response) = try await session.download(from: dmgURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateFailure.noRelease }
        let dmg = work.appendingPathComponent("Sottodesu.dmg")
        try fm.moveItem(at: downloaded, to: dmg)
        guard try sha256(of: dmg) == expected else { throw UpdateFailure.checksumMismatch }

        let staged = parent.appendingPathComponent(".Sottodesu-update-\(UUID().uuidString).app", isDirectory: true)
        let mount = work.appendingPathComponent("volume", isDirectory: true)
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)

        try await Task.detached {
            guard run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-quiet", "-mountpoint", mount.path]) == 0 else {
                throw UpdateFailure.damaged
            }
            defer { _ = run("/usr/bin/hdiutil", ["detach", mount.path, "-force", "-quiet"]) }
            let source = mount.appendingPathComponent("Sottodesu.app")
            guard fm.fileExists(atPath: source.path) else { throw UpdateFailure.damaged }
            try fm.copyItem(at: source, to: staged)
        }.value

        // Make sure what we are about to install really is Sottodesu, and newer than this copy.
        guard let bundle = Bundle(url: staged),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let version = AppVersion(bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""),
              version > (UpdateService.currentVersion ?? AppVersion("0")!) else {
            try? fm.removeItem(at: staged)
            throw UpdateFailure.damaged
        }
        return StagedUpdate(stagedApp: staged, destination: destination)
    }

    /// Quits, swaps the new copy in, and opens it. The swap is done by a tiny shell script that waits
    /// for this process to end; if it fails half-way the old copy is put back.
    @MainActor
    static func relaunch(_ update: StagedUpdate) {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if mv "$2" "$2.previous" && mv "$3" "$2"; then rm -rf "$2.previous"; else [ -e "$2" ] || mv "$2.previous" "$2"; rm -rf "$3"; fi
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier),
                             update.destination.path, update.stagedApp.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        NSApp.terminate(nil)
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    @discardableResult
    private static func run(_ tool: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return -1 }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

enum UpdateNotifier {
    static func post(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sottodesu"
        content.body = String(localized: "Sottodesu \(version) is available. Open Sottodesu to update.")
        let request = UNNotificationRequest(identifier: "update-\(version)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
