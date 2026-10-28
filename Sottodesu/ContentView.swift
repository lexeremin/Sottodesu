import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    private var tabBinding: Binding<AppTab> {
        Binding(get: { model.tab }, set: { model.tab = $0 })
    }

    var body: some View {
        Group {
            switch model.tab {
            case .sort: SortView()
            case .report: ReportView()
            case .largest: LargestFilesView()
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: tabBinding) {
                    ForEach(AppTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 330)
            }
        }
    }
}

// MARK: - Sort tab

struct SortView: View {
    @Environment(AppModel.self) private var model

    private var askAboutProject: Binding<Bool> {
        Binding(get: { model.askAboutProject }, set: { model.askAboutProject = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                LocationPicker()
                ScopePicker()
                sortSection
                history
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .confirmationDialog("This looks like a project folder", isPresented: askAboutProject, titleVisibility: .visible) {
            Button("Sort Anyway") { model.sort() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sorting moves files into subfolders by type, which can break a project. Sort it anyway?")
        }
    }

    private var sortSection: some View {
        VStack(spacing: 14) {
            Button {
                model.requestSort()
            } label: {
                Text("Sort \(model.locationName)")
            }
            .buttonStyle(SortButtonStyle())
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canSort)

            Text(model.scopeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if model.isWorking {
                    ProgressView().controlSize(.small)
                }
                Text(model.status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let run = model.undoableLastRun {
                    Button("Undo") { model.undo(run) }
                        .buttonStyle(.link)
                        .disabled(!model.canWork)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var history: some View {
        if model.runs.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("No history yet")
                    .font(.headline)
                Text("Each sort shows up here so you can look back at it or undo it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("History")
                        .font(.title3.weight(.semibold))
                    Text("\(model.runs.count) sorts")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("See report") { model.tab = .report }
                        .buttonStyle(.link)
                }
                LazyVStack(spacing: 10) {
                    ForEach(model.runs) { run in
                        RunCard(run: run)
                    }
                }
            }
        }
    }
}

private struct MoveGroup: Identifiable {
    let name: String
    let moves: [LoggedMove]

    var id: String { name }
    var bytes: Int64 { moves.reduce(0) { $0 + $1.size } }
}

private struct RunCard: View {
    let run: RunSummary
    @Environment(AppModel.self) private var model
    @State private var expanded = false
    @State private var moves: [LoggedMove] = []
    @State private var confirmUndo = false

    /// How many items to list per category before collapsing the rest into "and N more".
    private let listLimit = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded {
                Divider().padding(.horizontal, 14)
                details
            }
        }
        .cardBackground()
        .confirmationDialog("Undo this sort?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Undo \(run.remaining) items") { model.undo(run) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everything goes back to where it was. Items you’ve since moved or deleted are skipped.")
        }
        // Load the item list only when the card is opened, and refresh it after an undo.
        .task(id: "\(expanded)-\(run.reverted)") {
            if expanded { moves = model.moves(for: run) }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .frame(width: 12, height: 20)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .fontWeight(.medium)
                            if let place = model.displayName(forPath: run.location) {
                                Label(place, systemImage: "folder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                            }
                        }
                        Text(run.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        CategoryBar(counts: run.categories)
                            .padding(.top, 2)
                        Text(run.breakdown)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(LocalizedStringKey(expanded ? "Expanded" : "Collapsed"))
            .accessibilityHint("Shows the items in this sort")

            trailing
        }
        .padding(14)
    }

    @ViewBuilder
    private var trailing: some View {
        if run.isFullyReverted {
            Label("Undone", systemImage: "arrow.uturn.backward")
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            Button("Undo") { confirmUndo = true }
                .disabled(!model.canWork)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label {
                            Text(verbatim: "\(Localized.string(group.name)) · \(group.moves.count)")
                        } icon: {
                            Image(systemName: FileCategory.symbol(for: group.name))
                                .foregroundStyle(Theme.color(forGroup: group.name))
                        }
                        .font(.callout.weight(.semibold))
                        Spacer()
                        Text(formatBytes(group.bytes))
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    ForEach(group.moves.prefix(listLimit)) { move in
                        HStack {
                            Text(move.fileName)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            if move.revertedAt != nil {
                                Text("Restored").foregroundStyle(.secondary)
                            } else {
                                Text(formatBytes(move.size))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.callout)
                        .padding(.leading, 26)
                    }
                    if group.moves.count > listLimit {
                        Text("and \(group.moves.count - listLimit) more")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 26)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    private var groups: [MoveGroup] {
        Dictionary(grouping: moves, by: \.category)
            .map { MoveGroup(name: $0.key, moves: $0.value) }
            .sorted {
                let (a, b) = (FileCategory.order(of: $0.name), FileCategory.order(of: $1.name))
                return a == b ? $0.name < $1.name : a < b
            }
    }
}
