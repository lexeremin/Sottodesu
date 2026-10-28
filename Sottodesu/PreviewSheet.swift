import SwiftUI

/// "Here is what would move" — shown before anything does, with a checkbox per item.
struct PreviewSheet: View {
    let preview: SortPreview
    @Environment(AppModel.self) private var model
    @State private var excluded: Set<String> = []

    private var chosenCount: Int { preview.items.count - excluded.count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview")
                    .font(.title2.weight(.semibold))
                Text("Nothing has moved yet. Untick anything you want to leave where it is.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(preview.groups) { group in
                        groupView(group)
                    }
                    if preview.skipped > 0 {
                        Text("\(preview.skipped) items skipped (still downloading or just added).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("Cancel", role: .cancel) { model.preview = nil }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    let paths = Set(preview.items.map(\.id)).subtracting(excluded)
                    model.preview = nil
                    model.sort(only: paths)
                } label: {
                    Text("Sort \(chosenCount) items")
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(chosenCount == 0)
            }
            .padding(16)
        }
        .frame(width: 560, height: 560)
    }

    private func groupView(_ group: PreviewGroup) -> some View {
        let allOn = group.items.allSatisfy { !excluded.contains($0.id) }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label {
                    Text(verbatim: "\(group.category.displayName) · \(group.items.count)")
                } icon: {
                    Image(systemName: group.category.symbol)
                        .foregroundStyle(group.category.color)
                }
                .font(.callout.weight(.semibold))
                Spacer()
                Button(allOn ? "Untick all" : "Tick all") {
                    if allOn {
                        excluded.formUnion(group.items.map(\.id))
                    } else {
                        excluded.subtract(group.items.map(\.id))
                    }
                }
                .buttonStyle(.link)
                .font(.callout)
            }

            ForEach(group.items.prefix(200)) { item in
                Toggle(isOn: Binding(
                    get: { !excluded.contains(item.id) },
                    set: { isOn in
                        if isOn { excluded.remove(item.id) } else { excluded.insert(item.id) }
                    }
                )) {
                    HStack {
                        Text(item.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if let size = item.size {
                            Text(formatBytes(size))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        } else if item.isFolder {
                            Text("Folder").foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                }
                .toggleStyle(.checkbox)
                .padding(.leading, 26)
            }
            if group.items.count > 200 {
                Text("and \(group.items.count - 200) more")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 26)
            }
        }
    }
}
