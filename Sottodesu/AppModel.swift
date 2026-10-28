import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var runs: [RunSummary] = []
    var status = "Ready to sort your Downloads."
    var isWorking = false

    private let store: HistoryStore?
    private let downloads = AppPaths.downloads

    init() {
        do {
            store = try HistoryStore(databaseURL: AppPaths.database)
        } catch {
            store = nil
            status = "Couldn’t open the history: \(error.localizedDescription)"
        }
        reload()
    }

    var canWork: Bool { store != nil && !isWorking }

    func reload() {
        runs = (try? store?.runs()) ?? []
    }

    func moves(for run: RunSummary) -> [LoggedMove] {
        (try? store?.moves(forRun: run.id)) ?? []
    }

    func sort() {
        guard canWork, let store else { return }
        isWorking = true
        status = "Sorting…"
        let root = downloads

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) { () -> SortSummary in
                    let runID = try store.beginRun()
                    let result = try Sorter(root: root).sort { try store.record($0, runID: runID) }
                    if result.moved == 0 { try store.discardRun(runID) }
                    return result
                }.value
                status = Self.message(for: summary)
            } catch {
                status = "Stopped: \(Self.describe(error))"
            }
            isWorking = false
            reload()
        }
    }

    func undo(_ run: RunSummary) {
        guard canWork, let store else { return }
        isWorking = true
        status = "Undoing…"

        Task {
            do {
                let summary = try await Task.detached(priority: .userInitiated) { () -> UndoSummary in
                    let moves = try store.moves(forRun: run.id)
                    return try Reverter.revert(moves: moves, store: store)
                }.value
                status = Self.message(for: summary)
            } catch {
                status = "Stopped: \(Self.describe(error))"
            }
            isWorking = false
            reload()
        }
    }

    // MARK: - Messages

    private static func files(_ n: Int) -> String { n == 1 ? "1 file" : "\(n) files" }

    private static func message(for summary: SortSummary) -> String {
        var text = summary.moved == 0 ? "Nothing to sort." : "Sorted \(files(summary.moved))."
        if summary.skipped > 0 {
            text += " \(files(summary.skipped)) skipped (still downloading or just added)."
        }
        return text
    }

    private static func message(for summary: UndoSummary) -> String {
        var text = "Restored \(files(summary.restored))."
        if summary.missing > 0 {
            text += " \(files(summary.missing)) had been moved or deleted."
        }
        if summary.blocked > 0 {
            text += " \(files(summary.blocked)) couldn’t be restored because a file with that name is already there."
        }
        return text
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain,
           ns.code == NSFileReadNoPermissionError || ns.code == NSFileWriteNoPermissionError {
            return "Sottodesu can’t access your Downloads folder. Allow it in System Settings › Privacy & Security › Files & Folders."
        }
        return error.localizedDescription
    }
}
