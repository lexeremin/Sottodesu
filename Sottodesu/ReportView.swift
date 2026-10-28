import Charts
import SwiftUI

private func percent(_ part: Int64, of total: Int64) -> String {
    (Double(part) / Double(max(total, 1))).formatted(.percent.precision(.fractionLength(0)))
}

struct ReportView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                historySection
                spaceSection
            }
            .padding(24)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .task { model.scanIfNeeded() }
    }

    private func sectionHeader(_ title: LocalizedStringKey, _ subtitle: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("History", "Everything Sottodesu has sorted for you.")
            if model.report.sorts == 0 {
                Card {
                    ContentUnavailableView(
                        "Nothing sorted yet",
                        systemImage: "chart.bar",
                        description: Text("Sort your Downloads and this report fills in.")
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                historyTiles
                categoriesCard
            }
        }
    }

    private var historyTiles: some View {
        let r = model.report
        let average = r.sorts > 0 ? Int((Double(r.items) / Double(r.sorts)).rounded()) : 0
        let perSort = r.sorts > 0 ? String(localized: "about \(average) per sort") : nil
        let undoneShare = r.items > 0
            ? String(localized: "\(percent(Int64(r.undone), of: Int64(r.items))) of items")
            : nil
        let since = r.firstSort.map {
            String(localized: "since \($0.formatted(date: .abbreviated, time: .omitted))")
        }
        let top = r.categories.first
        let topName = top.map { Localized.string($0.name) } ?? "–"
        let topDetail = top.map { String(localized: "\($0.count) items") }
        let lastDay = r.lastSort?.formatted(date: .abbreviated, time: .omitted) ?? "–"
        let lastTime = r.lastSort?.formatted(date: .omitted, time: .shortened)

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            StatTile(title: "Sorts", value: "\(r.sorts)", detail: since)
            StatTile(title: "Items sorted", value: "\(r.items)", detail: perSort)
            StatTile(title: "Data moved", value: formatBytes(r.bytes))
            StatTile(title: "Undone", value: "\(r.undone)", detail: undoneShare)
            StatTile(title: "Most sorted", value: topName, detail: topDetail)
            StatTile(title: "Last sort", value: lastDay, detail: lastTime)
        }
    }

    private var categoriesCard: some View {
        let stats = model.report.categories
        let maxCount = max(stats.map(\.count).max() ?? 1, 1)

        return Card("What gets sorted", subtitle: "Items and data moved, by category") {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Text("Category").frame(width: 150, alignment: .leading)
                    Spacer()
                    Text("Items").frame(width: 52, alignment: .trailing)
                    Text("Data moved").frame(width: 96, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(stats) { stat in
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Theme.color(forGroup: stat.name))
                                .frame(width: 8, height: 8)
                            Text(Localized.string(stat.name)).lineLimit(1)
                        }
                        .frame(width: 150, alignment: .leading)

                        ShareBar(fraction: Double(stat.count) / Double(maxCount),
                                 color: Theme.color(forGroup: stat.name))

                        Text("\(stat.count)")
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                        Text(formatBytes(stat.bytes))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 96, alignment: .trailing)
                    }
                    .font(.callout)
                }
            }
        }
    }

    // MARK: - Disk space

    private var spaceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                sectionHeader("Disk space", "What’s in your Downloads folder right now.")
                Spacer()
                if model.isScanning {
                    ProgressView().controlSize(.small)
                }
                Button("Rescan") { model.rescan() }
                    .disabled(model.isScanning)
            }

            if let scan = model.scan {
                if scan.totalCount == 0 {
                    Card {
                        ContentUnavailableView("Downloads is empty", systemImage: "tray")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    spaceTiles(scan)
                    donutCard(scan)
                    biggestCard(scan)
                }
            } else {
                Card {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Measuring Downloads…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
        }
    }

    private func spaceTiles(_ scan: ScanResult) -> some View {
        let unsorted = scan.groups.first { $0.name == ScanGroup.unsorted }
        let biggest = scan.largest.first
        let measured = String(localized: "measured \(scan.scannedAt.formatted(date: .omitted, time: .shortened))")
        let places = String(localized: "in \(scan.groups.count) places")
        let unsortedDetail = unsorted.map { String(localized: "\($0.count) items") }
            ?? String(localized: "everything is sorted")

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            StatTile(title: "Total size", value: formatBytes(scan.totalBytes), detail: measured)
            StatTile(title: "Files", value: scan.totalCount.formatted(), detail: places)
            StatTile(title: "Largest file", value: biggest.map { formatBytes($0.size) } ?? "–", detail: biggest?.name)
            StatTile(title: "Not sorted yet", value: formatBytes(unsorted?.bytes ?? 0), detail: unsortedDetail)
        }
    }

    private func donutCard(_ scan: ScanResult) -> some View {
        let groups = scan.groups.filter { $0.bytes > 0 }
        let ids = groups.map(\.name)
        let colors = ids.map { Theme.color(forGroup: $0) }

        return Card("Where the space goes", subtitle: "Size by folder") {
            HStack(alignment: .center, spacing: 32) {
                Chart(groups) { group in
                    SectorMark(
                        angle: .value("Size", group.bytes),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(3)
                    .foregroundStyle(by: .value("Folder", group.name))
                }
                .chartForegroundStyleScale(domain: ids, range: colors)
                .chartLegend(.hidden)
                .frame(width: 210, height: 210)
                .overlay {
                    VStack(spacing: 2) {
                        Text(formatBytes(scan.totalBytes))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text("in Downloads")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("Size by folder")

                VStack(spacing: 10) {
                    ForEach(groups) { group in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Theme.color(forGroup: group.name))
                                .frame(width: 8, height: 8)
                            Text(Localized.string(group.name)).lineLimit(1)
                            Spacer(minLength: 8)
                            Text(percent(group.bytes, of: scan.totalBytes))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                            Text(formatBytes(group.bytes))
                                .monospacedDigit()
                                .frame(width: 76, alignment: .trailing)
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }

    private func biggestCard(_ scan: ScanResult) -> some View {
        Card("Biggest file in each folder", subtitle: "Use the arrow to show a file in Finder") {
            VStack(spacing: 10) {
                ForEach(scan.groups) { group in
                    if let file = group.largest {
                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Theme.color(forGroup: group.name))
                                    .frame(width: 8, height: 8)
                                Text(Localized.string(group.name)).lineLimit(1)
                            }
                            .frame(width: 150, alignment: .leading)

                            Text(file.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(formatBytes(file.size))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)

                            Button {
                                model.reveal([file.url])
                            } label: {
                                Image(systemName: "arrow.up.right.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Show in Finder")
                            .accessibilityLabel("Show \(file.name) in Finder")
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }
}
