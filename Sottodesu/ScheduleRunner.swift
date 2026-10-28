import Foundation
import ServiceManagement
import UserNotifications

/// Carries out schedules. Used by the background agent and by "Run now" in the app.
enum ScheduleRunner {
    struct Outcome: Equatable {
        let scheduleID: Int64
        let folderName: String
        let moved: Int
        let runID: Int64?
        let error: String?
    }

    /// Scheduled sorts leave anything newer than this alone, so a file you just downloaded isn't swept away.
    static let minimumAge: TimeInterval = 600

    /// Runs every schedule that is due. Safe to call as often as you like.
    @discardableResult
    static func runDue(store: HistoryStore, now: Date = Date()) -> [Outcome] {
        guard store.setting("schedulesPaused") != "1" else { return [] }
        var outcomes: [Outcome] = []
        for schedule in (try? store.schedules()) ?? [] where schedule.isDue(now: now) {
            outcomes.append(run(schedule, store: store, now: now))
        }
        return outcomes
    }

    /// Sorts the schedule's folder now and records the run (marked "scheduled") in the history.
    /// `rootOverride` exists for tests.
    static func run(_ schedule: Schedule, store: HistoryStore, now: Date = Date(),
                    minimumAge: TimeInterval = ScheduleRunner.minimumAge,
                    rootOverride: URL? = nil) -> Outcome {
        let name = schedule.folderName
        guard let root = rootOverride ?? schedule.rootURL,
              FileManager.default.fileExists(atPath: root.path) else {
            try? store.markScheduleRan(schedule.id, at: now, result: "error:folder")
            return Outcome(scheduleID: schedule.id, folderName: name, moved: 0, runID: nil, error: "folder")
        }
        do {
            let runID = try store.beginRun(at: now, location: root.path, source: "scheduled")
            let summary = try Sorter(root: root, minimumAge: minimumAge, policy: schedule.policy,
                                     selection: schedule.selection)
                .sort(now: now) { try store.record($0, runID: runID) }
            if summary.moved == 0 { try store.discardRun(runID) }
            try? store.markScheduleRan(schedule.id, at: now, result: "moved:\(summary.moved)")
            return Outcome(scheduleID: schedule.id, folderName: name, moved: summary.moved,
                           runID: summary.moved > 0 ? runID : nil, error: nil)
        } catch {
            try? store.markScheduleRan(schedule.id, at: now, result: "error:\(error.localizedDescription)")
            return Outcome(scheduleID: schedule.id, folderName: name, moved: 0, runID: nil,
                           error: error.localizedDescription)
        }
    }
}

/// What the background agent does when macOS starts it: run what is due, tell you, and quit.
enum BackgroundRun {
    static func execute() -> Never {
        if let store = try? HistoryStore(databaseURL: AppPaths.database) {
            ScheduleNotifier.post(ScheduleRunner.runDue(store: store))
        }
        exit(0)
    }
}

enum ScheduleNotifier {
    /// Asked once, when the first schedule is saved.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func post(_ outcomes: [ScheduleRunner.Outcome]) {
        let total = outcomes.reduce(0) { $0 + $1.moved }
        guard total > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Sottodesu"
        content.body = String(localized: "Tidied up \(total) items. Open Sottodesu to look or undo.")
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        let done = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().add(request) { _ in done.signal() }
        _ = done.wait(timeout: .now() + 5)
    }
}

/// The login-item agent that wakes the app up every half hour to run what is due.
/// Its description lives inside the app (Contents/Library/LaunchAgents), so nothing is copied to your
/// Library, and removing it is one call.
enum SchedulerAgent {
    static let plistName = "dev.sottodesu.app.scheduler.plist"

    private static var service: SMAppService { SMAppService.agent(plistName: plistName) }

    static var status: SMAppService.Status { service.status }

    /// Registers the agent while at least one schedule is switched on, and removes it otherwise.
    static func sync(hasActiveSchedules: Bool) {
        if hasActiveSchedules {
            if service.status != .enabled { try? service.register() }
        } else {
            unregister()
        }
    }

    static func unregister() {
        try? service.unregister()
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
