import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let allLocations = "All locations"

struct LargestFilesView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var location = allLocations
    @State private var selection = Set<URL>()
    @State private var sortOrder = [KeyPathComparator(\ScannedItem.size, order: .reverse)]

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            content
            Divider()
            footer
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search files")
        .task { model.scanIfNeeded() }
    }

    // MARK: - Pieces

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Location", selection: $location) {
                Text(allLocations).tag(allLocations)
                if let groups = model.scan?.groups {
                    Divider()
                    ForEach(groups) { group in
                        Text(verbatim: "\(Localized.string(group.name)) (\(group.count))").tag(group.name)
                    }
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 240)

            Spacer()

            if model.isScanning {
                ProgressView().controlSize(.small)
            }
            Button {
                model.rescan()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .disabled(model.isScanning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let scan = model.scan {
            let items = filtered(scan)
            if items.isEmpty {
                if query.isEmpty && location == allLocations {
                    ContentUnavailableView(
                        "No files in \(model.locationName)",
                        systemImage: "tray",
                        description: Text("Once files land here, the biggest ones show up in this list.")
                    )
                } else {
                    ContentUnavailableView.search(text: query)
                }
            } else {
                table(items)
            }
        } else {
            VStack(spacing: 10) {
                ProgressView()
                Text("Measuring \(model.locationName)…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func table(_ items: [ScannedItem]) -> some View {
        let biggest = max(items.map(\.size).max() ?? 1, 1)

        return Table(items, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                HStack(spacing: 8) {
                    Image(nsImage: fileIcon(for: item.url))
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(item.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            TableColumn("Size", value: \.size) { item in
                Text(formatBytes(item.size))
                    .monospacedDigit()
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(alignment: .leading) {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.14))
                                .frame(width: geo.size.width * CGFloat(Double(item.size) / Double(biggest)))
                        }
                    }
            }
            .width(min: 90, ideal: 110, max: 160)

            TableColumn("Location", value: \.folderPath) { item in
                Text(item.folderPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            TableColumn("Modified", value: \.modifiedDate) { item in
                Text(item.modifiedDate, format: .dateTime.day().month(.abbreviated).year())
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 110, max: 140)
        }
        .contextMenu(forSelectionType: URL.self) { urls in
            if !urls.isEmpty {
                Button("Show in Finder") { model.reveal(urls) }
                Button("Open") { model.open(urls) }
                Divider()
                Button("Copy Path") { model.copyPaths(urls) }
            }
        } primaryAction: { urls in
            // Double-click (or Return) shows the file in Finder.
            model.reveal(urls)
        }
    }

    private var footer: some View {
        HStack {
            if let scan = model.scan {
                Text("Files shown: \(scan.largest.count) of \(scan.totalCount.formatted()) · \(formatBytes(scan.totalBytes)) in total")
            }
            Spacer()
            Text("Double-click a file to show it in Finder")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Data

    private func filtered(_ scan: ScanResult) -> [ScannedItem] {
        scan.largest
            .filter { location == allLocations || $0.group == location }
            .filter {
                query.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(query)
                    || $0.folderPath.localizedCaseInsensitiveContains(query)
            }
            .sorted(using: sortOrder)
    }
}

/// The file's own icon, or the icon for its type if the file isn't on disk (as in demo mode).
private func fileIcon(for url: URL) -> NSImage {
    if FileManager.default.fileExists(atPath: url.path) {
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    return NSWorkspace.shared.icon(for: UTType(filenameExtension: url.pathExtension) ?? .data)
}
