import AppKit
import Foundation
import Observation
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case sort, report, largest

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .sort: return "Sort"
        case .report: return "Report"
        case .largest: return "Largest Files"
        }
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
    var status = String(localized: "Ready to sort your Downloads.")
    var isWorking = false
    private(set) var lastSortRunID: Int64?

    private let store: HistoryStore?
    private let downloads = AppPaths.downloads
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
        reload()
    }

    var canWork: Bool { store != nil && !isWorking }

    /// The sort that just happened, as long as it hasn't been undone — shown as an inline Undo.
    var undoableLastRun: RunSummary? {
        guard let id = lastSortRunID else { return nil }
        return runs.first { $0.id == id && !$0.isFullyReverted }
    }

    func reload() {
        runs = (try? store?.runs()) ?? []
        report = (try? store?.report()) ?? HistoryReport()
    }

    func moves(for run: RunSummary) -> [LoggedMove] {
        (try? store?.moves(forRun: run.id)) ?? []
    }

    // MARK: - Sorting

    func sort() {
        guard canWork, let store else { return }
        isWorking = true
        status = String(localized: "Sorting…")
        let root = downloads

        Task {
            do {
                let outcome = try await Task.detached(priority: .userInitiated) { () -> (SortSummary, Int64?) in
                    let runID = try store.beginRun()
                    let result = try Sorter(root: root).sort { try store.record($0, runID: runID) }
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

    // MARK: - Measuring Downloads

    func scanIfNeeded() {
        if scan == nil || scanIsStale { rescan() }
    }

    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let root = downloads
        let generation = changeCount

        Task {
            let result = await Task.detached(priority: .utility) { DownloadsScanner.scan(root: root) }.value
            scan = result
            scanIsStale = generation != changeCount
            isScanning = false
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
            return String(localized: "Sottodesu can’t access your Downloads folder. Allow it in System Settings › Privacy & Security › Files & Folders.")
        }
        return error.localizedDescription
    }
}
