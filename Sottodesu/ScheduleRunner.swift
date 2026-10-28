import Foundation
import ServiceManagement
import UserNotifications

/// Carries out schedules. The app checks for due ones every minute while it is running; "Run Now" uses it too.
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
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

/// An earlier test version registered a launchd background item, which macOS refuses to start for apps
/// without an Apple Developer signature. This only makes sure no such item is left behind.
enum LegacyAgent {
    static func remove() {
        try? SMAppService.agent(plistName: "dev.sottodesu.app.scheduler.plist").unregister()
    }
}

/// "Open at login": starts Sottodesu when you log in (it then stays in the menu bar).
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func set(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
