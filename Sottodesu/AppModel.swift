import AppKit
import Foundation
import Observation
import ServiceManagement
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case sort, report, largest, schedule

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .sort: return "Sort"
        case .report: return "Report"
        case .largest: return "Largest Files"
        case .schedule: return "Schedule"
        }
    }
}

/// Where the update check stands.
enum UpdateState: Equatable {
    case idle, checking, installing
    case failed(String)
}

/// Mirrors the "show in menu bar" choice for the app delegate, which has no access to the model.
enum MenuBarPreference {
    static var isEnabled = false
}

/// One file or folder in the preview, before anything moves.
struct PreviewItem: Identifiable, Equatable {
    let id: String          // the path
    let name: String
    let category: FileCategory
    let isFolder: Bool
    let size: Int64?
}

struct PreviewGroup: Identifiable, Equatable {
    let category: FileCategory
    let items: [PreviewItem]

    var id: String { category.rawValue }
}

/// What a sort would do right now, shown so the person can untick things before it happens.
struct SortPreview: Identifiable, Equatable {
    let id = UUID()
    let items: [PreviewItem]
    let skipped: Int

    init(plan: Sorter.Plan) {
        items = plan.candidates.map {
            PreviewItem(id: $0.url.path, name: $0.url.lastPathComponent, category: $0.category,
                        isFolder: $0.isFolder, size: $0.fileSize.map { Int64($0) })
        }
        skipped = plan.skipped
    }

    var groups: [PreviewGroup] {
        Dictionary(grouping: items, by: \.category)
            .map { PreviewGroup(category: $0.key, items: $0.value) }
            .sorted { FileCategory.order(of: $0.category.rawValue) < FileCategory.order(of: $1.category.rawValue) }
    }
}

@MainActor
@Observable
final class AppModel {
    var tab: AppTab = .sort
    var runs: [RunSummary] = []
    var report = HistoryReport()
    var scan: ScanResult?
    var isScanning = false
    var status = String(localized: "Ready to sort.")
    var isWorking = false
    /// Drives the "this looks like a project" confirmation.
    var askAboutProject = false
    private(set) var lastSortRunID: Int64?
    /// The "what would move" sheet, while it is open.
    var preview: SortPreview?
    var isPlanning = false

    // Schedules and the menu bar.
    var schedules: [Schedule] = []
    private(set) var schedulesPaused = false
    private(set) var showsMenuBarIcon = false
    /// When the app last looked for schedules that are due (it looks every minute while it is running).
    private(set) var lastScheduleCheck: Date?
    /// What the last check found, in words: "Nothing is due yet. Next: Downloads, 19:00."
    private(set) var scheduleCheckNote: String?
    private(set) var opensAtLogin = false
    private(set) var loginItemStatus: SMAppService.Status = .notRegistered
    private var scheduleTimer: Timer?
    /// Keeps macOS from napping the app when it only lives in the menu bar, which would delay schedules.
    private var napBlocker: NSObjectProtocol?

    // Updates
    private(set) var updateChecksEnabled = true
    private(set) var updateState: UpdateState = .idle
    private(set) var foundRelease: ReleaseInfo?
    private(set) var lastUpdateCheck: Date?
    private(set) var updateBannerHidden = false
    private var skippedVersion: String?

    // What to sort, and where.
    private(set) var location: LocationKind = .downloads
    private(set) var customFolder: URL?
    /// "Selective" mode sorts only the ticked types; in "Everything" mode the ticks are ignored.
    private(set) var isSelective = false
    private(set) var selectedCategories: Set<FileCategory> = []

    private let store: HistoryStore?
    /// Demo mode points the app at an empty temporary folder instead of a real one.
    private var rootOverride: URL?
    private var scanIsStale = true
    /// Bumped whenever files move, so a scan that was already running can tell it is out of date.
    private var changeCount = 0

    init() {
        do {
            store = try HistoryStore(databaseURL: AppPaths.database)
        } catch {
            store = nil
            status = String(localized: "Couldn’t open the history: \(error.localizedDescription)")
        }
        restoreSettings()
        reload()
        startScheduler()
    }

    /// For screenshots only (see DemoMode.swift): a made-up history and folder.
    init(demoStore: HistoryStore, downloads: URL, scan: ScanResult, status: String, lastSortRunID: Int64?) {
        self.store = demoStore
        self.rootOverride = downloads
        self.scan = scan
        self.status = status
        self.lastSortRunID = lastSortRunID
        scanIsStale = false
        reload()
    }

    var canWork: Bool { store != nil && !isWorking }

    // MARK: - Where and what

    var rootURL: URL {
        if let rootOverride { return rootOverride }
        switch location {
        case .downloads: return AppPaths.downloads
        case .desktop: return AppPaths.desktop
        case .home: return AppPaths.home
        case .custom: return customFolder ?? AppPaths.downloads
        }
    }

    var policy: SortPolicy { SortPolicy.policy(for: location) }
    var allowedCategories: Set<FileCategory> { policy.allowedCategories }
    /// What a sort will actually move: everything the location allows, or just the ticked types.
    var effectiveSelection: Set<FileCategory> {
        isSelective ? selectedCategories.intersection(allowedCategories) : allowedCategories
    }
    var isEverythingSelected: Bool { !isSelective }
    /// A selective sort needs at least one type ticked.
    var canSort: Bool { canWork && !effectiveSelection.isEmpty }

    /// The folder's name as shown in the interface ("Downloads", or the custom folder's name).
    var locationName: String {
        location == .custom ? (customFolder?.lastPathComponent ?? LocationKind.custom.title) : location.title
    }

    /// "All file types", or "Images · Documents".
    var scopeSummary: String {
        if isEverythingSelected { return String(localized: "All file types") }
        if effectiveSelection.isEmpty { return String(localized: "Pick at least one type") }
        return FileCategory.allCases
            .filter { effectiveSelection.contains($0) }
            .map(\.displayName)
            .joined(separator: " · ")
    }

    /// A friendly name for a folder path recorded in the history.
    func displayName(forPath path: String?) -> String? {
        guard let path else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        if url.path == AppPaths.downloads.standardizedFileURL.path { return LocationKind.downloads.title }
        if url.path == AppPaths.desktop.standardizedFileURL.path { return LocationKind.desktop.title }
        if url.path == AppPaths.home.standardizedFileURL.path { return LocationKind.home.title }
        return url.lastPathComponent
    }

    func choose(_ kind: LocationKind) {
        if kind == .custom, customFolder == nil || location == .custom {
            chooseCustomFolder()
        } else {
            setLocation(kind)
        }
    }

    func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = String(localized: "Choose a folder to sort")
        panel.prompt = String(localized: "Choose")
        panel.directoryURL = customFolder ?? AppPaths.home
        guard panel.runModal() == .OK, let url = panel.url else { return }
        select(customFolder: url)
    }

    func select(customFolder url: URL) {
        guard FolderGuard.isAllowedCustomFolder(url) else {
            status = String(localized: "Sottodesu won’t sort system folders, your Library, apps or hidden folders. To tidy your home folder, use Home.")
            return
        }
        customFolder = url
        setLocation(.custom)
    }

    private func setLocation(_ kind: LocationKind) {
        guard kind != location || kind == .custom else { return }
        location = kind
        isSelective = false
        selectedCategories = []
        scan = nil
        scanIsStale = true
        status = String(localized: "Ready to sort.")
        saveSettings()
    }

    func chooseEverything() {
        isSelective = false
        saveSettings()
    }

    func chooseSelective() {
        isSelective = true
        saveSettings()
    }

    /// Clears the ticked types (staying in Selective) so you can start over.
    func resetSelection() {
        selectedCategories = []
        saveSettings()
    }

    /// Ticks or unticks a type. Only meaningful in Selective mode.
    func toggle(_ category: FileCategory) {
        guard isSelective, allowedCategories.contains(category) else { return }
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        saveSettings()
    }

    // MARK: - Remembering the choice (in the same file as the history)

    private func saveSettings() {
        guard let store, rootOverride == nil else { return }
        try? store.setSetting("location", location.rawValue)
        try? store.setSetting("customPath", customFolder?.path)
        try? store.setSetting("scope", isSelective ? "selective" : "all")
        try? store.setSetting("categories", selectedCategories.map(\.rawValue).sorted().joined(separator: ","))
    }

    private func restoreSettings() {
        guard let store else { return }

        if let path = store.setting("customPath") {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path), FolderGuard.isAllowedCustomFolder(url) {
                customFolder = url
            }
        }
        if let raw = store.setting("location"), let saved = LocationKind(rawValue: raw) {
            if saved == .custom && customFolder == nil {
                status = String(localized: "The folder you chose is no longer available, so Sottodesu switched back to Downloads.")
            } else {
                location = saved
            }
        }

        schedulesPaused = store.setting("schedulesPaused") == "1"
        showsMenuBarIcon = store.setting("menuBar") == "1"
        MenuBarPreference.isEnabled = showsMenuBarIcon

        updateChecksEnabled = store.setting("updateChecks") != "0"
        skippedVersion = store.setting("skippedVersion")
        lastUpdateCheck = store.setting("lastUpdateCheck").flatMap(Double.init).map { Date(timeIntervalSince1970: $0) }

        let allowed = allowedCategories
        isSelective = store.setting("scope") == "selective"
        let raw = store.setting("categories") ?? ""
        selectedCategories = Set(raw.split(separator: ",").compactMap { FileCategory(rawValue: String($0)) })
            .intersection(allowed)
    }

    // MARK: - History

    /// The sort that just happened, as long as it hasn't been undone — shown as an inline Undo.
    var undoableLastRun: RunSummary? {
        guard let id = lastSortRunID else { return nil }
        return runs.first { $0.id == id && !$0.isFullyReverted }
    }

    func reload() {
        runs = (try? store?.runs()) ?? []
        report = (try? store?.report()) ?? HistoryReport()
        schedules = (try? store?.schedules()) ?? []
        loginItemStatus = LoginItem.status
        opensAtLogin = loginItemStatus == .enabled
    }

    func moves(for run: RunSummary) -> [LoggedMove] {
        (try? store?.moves(forRun: run.id)) ?? []
    }

    /// Finds moves by file name — "where did report.pdf go?".
    func search(_ text: String) -> [FoundMove] {
        (try? store?.search(text)) ?? []
    }

    // MARK: - Sorting

    /// Starts a sort — after asking, if the chosen folder looks like a software project.
    func requestSort() {
        guard canSort else { return }
        if location == .custom && FolderGuard.looksLikeProject(rootURL) {
            askAboutProject = true
        } else {
            sort()
        }
    }

    func sort(only: Set<String>? = nil) {
        guard canSort, let store else { return }
        isWorking = true
        status = String(localized: "Sorting…")
        let root = rootURL
        let policy = self.policy
        let selection = effectiveSelection

        Task {
            do {
                let outcome = try await Task.detached(priority: .userInitiated) { () -> (SortSummary, Int64?) in
                    let runID = try store.beginRun(location: root.path)
                    let result = try Sorter(root: root, policy: policy, selection: selection)
                        .sort(only: only) { try store.record($0, runID: runID) }
                    if result.moved == 0 {
                        try store.discardRun(runID)
                        return (result, nil)
                    }
                    return (result, runID)
                }.value
                status = Self.message(for: outcome.0)
                lastSortRunID = outcome.1
            } catch {
                status = String(localized: "Stopped: \(Self.describe(error))")
            }
            filesDidChange()
        }
    }

    /// Works out what a sort would move and opens the preview, without moving anything.
    func showPreview() {
        guard canSort, !isPlanning else { return }
        isPlanning = true
        status = String(localized: "Looking at what would move…")
        let root = rootURL
        let policy = self.policy
        let selection = effectiveSelection

        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<Sorter.Plan, Error> in
                Result { try Sorter(root: root, policy: policy, selection: selection).plan() }
            }.value
            isPlanning = false
            switch result {
            case .success(let plan):
                if plan.candidates.isEmpty {
                    var summary = SortSummary()
                    summary.skipped = plan.skipped
                    status = Self.message(for: summary)
                } else {
                    status = String(localized: "Ready to sort.")
                    preview = SortPreview(plan: plan)
                }
            case .failure(let error):
                status = String(localized: "Stopped: \(Self.describe(error))")
            }
        }
    }

    /// Puts just these files back (one file, or one category of a run).
    func restore(_ moves: [LoggedMove]) {
        guard canWork, let store, !moves.isEmpty else { return }
        isWorking = true
        status = String(localized: "Undoing…")

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) { () -> UndoSummary in
                    try Reverter.revert(moves: moves, store: store)
                }.value
                status = Self.message(for: summary)
            } catch {
                status = String(localized: "Stopped: \(Self.describe(error))")
            }
            filesDidChange()
        }
    }

    func undo(_ run: RunSummary) {
        guard canWork, let store else { return }
        isWorking = true
        status = String(localized: "Undoing…")

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) { () -> UndoSummary in
                    let moves = try store.moves(forRun: run.id)
                    return try Reverter.revert(moves: moves, store: store)
                }.value
                status = Self.message(for: summary)
            } catch {
                status = String(localized: "Stopped: \(Self.describe(error))")
            }
            filesDidChange()
        }
    }

    private func filesDidChange() {
        isWorking = false
        changeCount += 1
        scanIsStale = true
        reload()
    }

    // MARK: - Schedules

    /// Saves a schedule and asks for what an automatic run will need (folder access, notifications).
    func save(_ schedule: Schedule) {
        guard let store else { return }
        _ = try? store.save(schedule)
        // Visit the folder now, while you are here, so macOS asks for access now rather than in the background.
        if let root = schedule.rootURL { _ = try? FileManager.default.contentsOfDirectory(atPath: root.path) }
        ScheduleNotifier.requestPermission()
        schedulesChanged()
    }

    func deleteSchedule(_ schedule: Schedule) {
        try? store?.deleteSchedule(schedule.id)
        schedulesChanged()
    }

    func setEnabled(_ enabled: Bool, for schedule: Schedule) {
        var changed = schedule
        changed.isEnabled = enabled
        save(changed)
    }

    func runNow(_ schedule: Schedule) {
        guard canWork, let store else { return }
        isWorking = true
        status = String(localized: "Sorting…")
        Task {
            let outcome = await Task.detached(priority: .userInitiated) {
                ScheduleRunner.run(schedule, store: store, minimumAge: 5)
            }.value
            if outcome.error != nil {
                status = String(localized: "That folder isn’t available.")
            } else {
                var summary = SortSummary()
                summary.moved = outcome.moved
                status = outcome.moved > 0
                    ? String(localized: "Tidied up \(outcome.moved) items in \(outcome.folderName).")
                    : Self.message(for: summary)
            }
            filesDidChange()
        }
    }

    func setSchedulesPaused(_ paused: Bool) {
        schedulesPaused = paused
        try? store?.setSetting("schedulesPaused", paused ? "1" : nil)
    }

    func setMenuBar(_ shown: Bool) {
        if !shown && opensAtLogin {
            LoginItem.set(false)
            loginItemStatus = LoginItem.status
            opensAtLogin = false
        }
        showsMenuBarIcon = shown
        MenuBarPreference.isEnabled = shown
        try? store?.setSetting("menuBar", shown ? "1" : nil)
    }

    private func schedulesChanged() {
        schedules = (try? store?.schedules()) ?? []
    }

    func openLoginItemsSettings() {
        LoginItem.openSystemSettings()
    }

    /// "Open at login" needs the menu bar icon, so Sottodesu can start quietly instead of opening a window.
    func setOpensAtLogin(_ enabled: Bool) {
        if enabled { setMenuBar(true) }
        LoginItem.set(enabled)
        loginItemStatus = LoginItem.status
        opensAtLogin = loginItemStatus == .enabled
    }

    // MARK: - Updates

    func setUpdateChecks(_ enabled: Bool) {
        updateChecksEnabled = enabled
        try? store?.setSetting("updateChecks", enabled ? nil : "0")
        if enabled { checkForUpdatesIfDue() }
    }

    /// Runs from the once-a-minute timer; only really checks if it is on and the last check was a day ago.
    func checkForUpdatesIfDue(now: Date = Date()) {
        guard updateChecksEnabled, rootOverride == nil else { return }
        if let last = lastUpdateCheck, now.timeIntervalSince(last) < 24 * 3600 { return }
        checkForUpdates(userInitiated: false)
    }

    /// `userInitiated` checks always run (and answer with an alert); automatic ones are silent unless
    /// there is something new.
    func checkForUpdates(userInitiated: Bool) {
        guard rootOverride == nil, updateState != .checking, updateState != .installing else { return }
        updateState = .checking
        Task {
            do {
                let release = try await UpdateService.fetchLatest()
                let now = Date()
                lastUpdateCheck = now
                try? store?.setSetting("lastUpdateCheck", String(Int(now.timeIntervalSince1970)))
                updateState = .idle
                guard let current = UpdateService.currentVersion, release.version > current else {
                    foundRelease = nil
                    if userInitiated { Self.showAlert(String(localized: "You’re up to date."),
                                                      String(localized: "Sottodesu \(UpdateService.currentVersion?.description ?? "") is the latest version.")) }
                    return
                }
                if !userInitiated && skippedVersion == release.tag { return }
                let isNew = foundRelease?.tag != release.tag
                foundRelease = release
                updateBannerHidden = false
                if !userInitiated && isNew && !NSApp.isActive { UpdateNotifier.post(version: release.tag) }
            } catch {
                updateState = .idle
                if userInitiated {
                    updateState = .failed(String(localized: "Couldn’t check for updates: \(error.localizedDescription)"))
                    Self.showAlert(String(localized: "Couldn’t check for updates."), error.localizedDescription)
                }
            }
        }
    }

    func installUpdate() {
        guard let release = foundRelease, updateState != .installing else { return }
        updateState = .installing
        Task {
            do {
                let staged = try await UpdateInstaller.stage(release)
                UpdateInstaller.relaunch(staged)
            } catch {
                updateState = .failed(String(localized: "Couldn’t install the update: \(error.localizedDescription)"))
            }
        }
    }

    func hideUpdateBanner() { updateBannerHidden = true }

    func skipFoundRelease() {
        guard let release = foundRelease else { return }
        skippedVersion = release.tag
        try? store?.setSetting("skippedVersion", release.tag)
        foundRelease = nil
    }

    private static func showAlert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }

    // MARK: - Running schedules (while the app is open or in the menu bar)

    /// Looks for due schedules every minute, and right after the Mac wakes up.
    private func startScheduler() {
        guard rootOverride == nil else { return }
        LegacyAgent.remove()

        napBlocker = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Checking for scheduled tidy-ups")
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSchedules()
                self?.checkForUpdatesIfDue()
            }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Give the network and disks a moment to come back.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                self?.checkSchedules()
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            checkSchedules()
            try? await Task.sleep(for: .seconds(5))
            checkForUpdatesIfDue()
        }
    }

    func checkSchedules() {
        guard let store, rootOverride == nil else { return }
        lastScheduleCheck = Date()
        guard !isWorking else {
            scheduleCheckNote = String(localized: "Busy with another sort. Checking again in a minute.")
            return
        }
        guard schedules.contains(where: \.isEnabled) else {
            scheduleCheckNote = String(localized: "No schedule is switched on.")
            return
        }
        guard !schedulesPaused else {
            scheduleCheckNote = String(localized: "Schedules are paused.")
            return
        }

        Task {
            let outcomes = await Task.detached(priority: .utility) { () -> [ScheduleRunner.Outcome] in
                let outcomes = ScheduleRunner.runDue(store: store)
                ScheduleNotifier.post(outcomes)
                return outcomes
            }.value
            if outcomes.isEmpty {
                scheduleCheckNote = nothingDueNote()
            } else {
                let total = outcomes.reduce(0) { $0 + $1.moved }
                if let failure = outcomes.compactMap(\.error).first {
                    scheduleCheckNote = String(localized: "A schedule couldn’t run: \(failure)")
                } else {
                    scheduleCheckNote = String(localized: "Tidied up \(total) items in the last check.")
                }
                changeCount += 1
                scanIsStale = true
                reload()
            }
        }
    }

    private func nothingDueNote() -> String {
        let upcoming = schedules.filter(\.isEnabled).compactMap { schedule -> (Schedule, Date)? in
            guard let next = schedule.nextRun(after: schedule.lastRunAt ?? schedule.createdAt) else { return nil }
            return (schedule, next)
        }.min { $0.1 < $1.1 }
        guard let (schedule, date) = upcoming else { return String(localized: "No schedule is switched on.") }
        return String(localized: "Nothing is due yet. Next: \(schedule.folderName), \(date.formatted(date: .abbreviated, time: .shortened)).")
    }

    // MARK: - Measuring the folder

    func scanIfNeeded() {
        if scan == nil || scanIsStale { rescan() }
    }

    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let root = rootURL
        let generation = changeCount
        let where_ = location

        Task {
            let result = await Task.detached(priority: .utility) { DownloadsScanner.scan(root: root) }.value
            // The person may have picked another folder while this was running.
            if where_ == location, root == rootURL {
                scan = result
                scanIsStale = generation != changeCount
            } else {
                scanIsStale = true
            }
            isScanning = false
            if scanIsStale && scan == nil && tab != .sort { rescan() }
        }
    }

    // MARK: - Files on disk

    func reveal(_ urls: Set<URL>) {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        if existing.count < urls.count {
            // Something moved since the last scan; refresh so the list doesn't lie.
            scanIsStale = true
            rescan()
        }
        guard !existing.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(Array(existing))
    }

    func open(_ urls: Set<URL>) {
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        }
    }

    func copyPaths(_ urls: Set<URL>) {
        let text = urls.map(\.path).sorted().joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Messages

    private static func message(for summary: SortSummary) -> String {
        guard summary.moved > 0 else {
            return summary.skipped > 0
                ? String(localized: "Nothing to sort yet: \(summary.skipped) items are still downloading or were just added.")
                : String(localized: "Nothing to sort.")
        }
        var text = String(localized: "Sorted \(summary.moved) items:") + " " + CategoryCount.describe(summary.categories)
        if summary.skipped > 0 {
            text += " " + String(localized: "\(summary.skipped) items skipped (still downloading or just added).")
        }
        return text
    }

    private static func message(for summary: UndoSummary) -> String {
        var text = String(localized: "Restored \(summary.restored) items.")
        if summary.missing > 0 {
            text += " " + String(localized: "\(summary.missing) items had been moved or deleted.")
        }
        if summary.blocked > 0 {
            text += " " + String(localized: "\(summary.blocked) items couldn’t be restored because something with that name is already there.")
        }
        return text
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain,
           ns.code == NSFileReadNoPermissionError || ns.code == NSFileWriteNoPermissionError {
            return String(localized: "Sottodesu can’t access this folder. Allow it in System Settings › Privacy & Security › Files & Folders.")
        }
        return error.localizedDescription
    }
}
