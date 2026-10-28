import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if model.runs.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Each time you sort, it shows up here so you can undo it.")
                )
            } else {
                List(model.runs) { run in
                    RunRow(run: run)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 440, minHeight: 480)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Button {
                model.sort()
            } label: {
                Text("Sort Downloads")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canWork)

            Text(model.status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

private struct RunRow: View {
    let run: RunSummary
    @Environment(AppModel.self) private var model
    @State private var expanded = false
    @State private var moves: [LoggedMove] = []

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(moves) { move in
                HStack {
                    Text(move.fileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(move.revertedAt == nil ? move.category : "Restored")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                    Text("^[\(run.total) file](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if run.isFullyReverted {
                    Text("Undone").foregroundStyle(.secondary)
                } else {
                    Button("Undo") { model.undo(run) }
                        .disabled(!model.canWork)
                }
            }
        }
        // Load the file list only when the row is opened, and refresh it after an undo.
        .task(id: "\(expanded)-\(run.reverted)") {
            if expanded { moves = model.moves(for: run) }
        }
    }
}
