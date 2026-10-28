import Foundation
import GRDB

enum ScheduleFrequency: String, CaseIterable, Identifiable {
    case daily, weekly, monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return String(localized: "Daily")
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        }
    }
}

/// "Tidy this folder up every day / week / month." Stored in the history database and carried out by
/// the background agent (or by "Run now" in the app).
struct Schedule: Identifiable, Equatable {
    /// 0 until the schedule has been saved.
    var id: Int64 = 0
    var location: LocationKind = .downloads
    var customPath: String?
    /// The types to sort; empty means everything the location allows.
    var categories: Set<FileCategory> = []
    var frequency: ScheduleFrequency = .daily
    var hour = 18
    var minute = 0
    /// Calendar weekday: 1 = Sunday … 7 = Saturday.
    var weekday = 2
    /// 1…28, so every month has the day.
    var dayOfMonth = 1
    var isEnabled = true
    var createdAt = Date()
    var lastRunAt: Date?
    /// "moved:12" or "error:…" after a run.
    var lastResult: String?

    init() {}

    init(row: Row) {
        id = row["id"]
        location = LocationKind(rawValue: row["location"]) ?? .downloads
        customPath = row["customPath"]
        let raw: String = row["categories"]
        categories = Set(raw.split(separator: ",").compactMap { FileCategory(rawValue: String($0)) })
        frequency = ScheduleFrequency(rawValue: row["frequency"]) ?? .daily
        hour = row["hour"]
        minute = row["minute"]
        weekday = row["weekday"]
        dayOfMonth = row["dayOfMonth"]
        let enabled: Int = row["enabled"]
        isEnabled = enabled != 0
        let created: Double = row["createdAt"]
        createdAt = Date(timeIntervalSince1970: created)
        let last: Double? = row["lastRunAt"]
        lastRunAt = last.map { Date(timeIntervalSince1970: $0) }
        lastResult = row["lastResult"]
    }

    // MARK: What it sorts

    /// The folder, or nil if it can't be sorted (not chosen, gone, or not allowed).
    var rootURL: URL? {
        switch location {
        case .downloads: return AppPaths.downloads
        case .desktop: return AppPaths.desktop
        case .home: return AppPaths.home
        case .custom:
            guard let customPath else { return nil }
            let url = URL(fileURLWithPath: customPath, isDirectory: true)
            return FolderGuard.isAllowedCustomFolder(url) ? url : nil
        }
    }

    var policy: SortPolicy { SortPolicy.policy(for: location) }

    /// nil means "everything the location allows".
    var selection: Set<FileCategory>? { categories.isEmpty ? nil : categories }

    var folderName: String {
        if location == .custom, let customPath { return URL(fileURLWithPath: customPath).lastPathComponent }
        return location.title
    }

    // MARK: When it runs

    /// The next time this schedule is due after `date`.
    func nextRun(after date: Date, calendar: Calendar = .current) -> Date? {
        var components = DateComponents(hour: hour, minute: minute, second: 0)
        switch frequency {
        case .daily: break
        case .weekly: components.weekday = weekday
        case .monthly: components.day = dayOfMonth
        }
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }

    /// Due when its next slot after the last run (or after it was created) has passed. A Mac that was
    /// asleep at the set time catches up as soon as it wakes, and a missed day never runs twice.
    func isDue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled, let next = nextRun(after: lastRunAt ?? createdAt, calendar: calendar) else { return false }
        return next <= now
    }

    /// "Daily at 18:00", "Weekly on Monday at 18:00", "Monthly on day 1 at 18:00".
    func describe(calendar: Calendar = .current) -> String {
        let time = (calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date())
            .formatted(date: .omitted, time: .shortened)
        switch frequency {
        case .daily:
            return String(localized: "Daily at \(time)")
        case .weekly:
            let name = calendar.weekdaySymbols[max(0, min(6, weekday - 1))]
            return String(localized: "Weekly on \(name) at \(time)")
        case .monthly:
            return String(localized: "Monthly on day \(dayOfMonth) at \(time)")
        }
    }

    var lastMoved: Int? {
        guard let lastResult, lastResult.hasPrefix("moved:") else { return nil }
        return Int(lastResult.dropFirst("moved:".count))
    }

    var lastError: String? {
        guard let lastResult, lastResult.hasPrefix("error:") else { return nil }
        return String(lastResult.dropFirst("error:".count))
    }
}
