import ServiceManagement
import SwiftUI

// MARK: - Schedule tab

struct ScheduleView: View {
    @Environment(AppModel.self) private var model
    /// nil = closed; a schedule with id 0 = adding a new one.
    @State private var editing: Schedule?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if model.loginItemStatus == .requiresApproval {
                    approvalNotice
                }
                if model.schedules.isEmpty {
                    emptyState
                } else {
                    backgroundStatus
                    VStack(spacing: 10) {
                        ForEach(model.schedules) { schedule in
                            ScheduleCard(schedule: schedule) { editing = schedule }
                        }
                    }
                }
                options
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $editing) { schedule in
            ScheduleEditor(schedule: schedule)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Schedule")
                    .font(.title2.weight(.semibold))
                Text("Tidy up a folder automatically while Sottodesu stays in the menu bar. Every automatic sort goes into your history, so you can undo it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Button {
                var fresh = Schedule()
                fresh.location = model.location == .home ? .downloads : model.location
                if fresh.location == .custom {
                    fresh.customPath = model.customFolder?.path
                }
                editing = fresh
            } label: {
                Label("Add Schedule", systemImage: "plus")
            }
            .controlSize(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No schedules yet")
                .font(.headline)
            Text("Add one to keep Downloads or your Desktop tidy without thinking about it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .cardBackground()
    }

    /// Says plainly when schedules can run, because they only run while the app is open.
    private var backgroundStatus: some View {
        let text: String
        if !model.showsMenuBarIcon {
            text = String(localized: "Schedules only run while Sottodesu is open. Switch on “Keep running in the menu bar” below to keep them going after you close the window.")
        } else if let last = model.lastScheduleCheck {
            text = String(localized: "Schedules run while Sottodesu is open or in the menu bar. Last check: \(last.formatted(date: .omitted, time: .shortened))")
        } else {
            text = String(localized: "Schedules run while Sottodesu is open or in the menu bar. Waiting for the first check.")
        }
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(text, systemImage: model.showsMenuBarIcon ? "checkmark.circle" : "exclamationmark.circle")
                if let note = model.scheduleCheckNote {
                    Text(note)
                        .padding(.leading, 22)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Check Now") { model.checkSchedules() }
                .buttonStyle(.link)
                .font(.caption)
                .disabled(!model.canWork)
        }
    }

    private var approvalNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.accentColor)
            Text("macOS needs your OK before Sottodesu can open at login. Switch it on under Login Items.")
                .font(.callout)
            Spacer()
            Button("Open Settings") { model.openLoginItemsSettings() }
        }
        .padding(14)
        .cardBackground()
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Options")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: Binding(get: { model.schedulesPaused }, set: { model.setSchedulesPaused($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause all schedules")
                        Text("Nothing runs automatically until you switch this off.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                Toggle(isOn: Binding(get: { model.showsMenuBarIcon }, set: { model.setMenuBar($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep running in the menu bar")
                        Text("Closing the window leaves Sottodesu in the menu bar, so schedules keep running. It also gets a Sort Now shortcut.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                Toggle(isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Open at login")
                        Text("Starts Sottodesu quietly in the menu bar when you log in.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
            .padding(14)
            .cardBackground()
        }
    }
}

// MARK: - One schedule

private struct ScheduleCard: View {
    let schedule: Schedule
    let edit: () -> Void
    @Environment(AppModel.self) private var model
    @State private var confirmDelete = false

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: schedule.location.symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))

            VStack(alignment: .leading, spacing: 3) {
                Text(schedule.folderName)
                    .font(.headline)
                Text(schedule.describe())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(scopeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let last = lastRunText {
                    Text(last)
                        .font(.caption)
                        .foregroundStyle(schedule.lastError == nil ? Color.secondary : Color.accentColor)
                }
                Text(nextRunText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                CardIconButton(symbol: "play.fill", help: "Run Now",
                               isDisabled: !model.canWork || schedule.rootURL == nil) { model.runNow(schedule) }
                CardIconButton(symbol: "pencil", help: "Edit…", action: edit)
                CardIconButton(symbol: "trash", help: "Delete", isDestructive: true) { confirmDelete = true }
            }

            Toggle("Enabled", isOn: Binding(get: { schedule.isEnabled },
                                            set: { model.setEnabled($0, for: schedule) }))
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(14)
        .cardBackground()
        .opacity(schedule.isEnabled ? 1 : 0.6)
        .onTapGesture(count: 2, perform: edit)
        .contextMenu {
            Button("Run Now") { model.runNow(schedule) }
                .disabled(!model.canWork || schedule.rootURL == nil)
            Button("Edit…", action: edit)
            Divider()
            Button("Delete", role: .destructive) { confirmDelete = true }
        }
        .confirmationDialog("Delete this schedule?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { model.deleteSchedule(schedule) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Files that were already sorted stay where they are.")
        }
    }

    private var scopeText: String {
        if schedule.categories.isEmpty { return String(localized: "All file types") }
        return FileCategory.allCases.filter { schedule.categories.contains($0) }
            .map(\.displayName).joined(separator: " · ")
    }

    private var lastRunText: String? {
        if let error = schedule.lastError {
            return error == "folder"
                ? String(localized: "Last run failed: the folder isn’t available.")
                : String(localized: "Last run failed: \(error)")
        }
        if let last = schedule.lastRunAt, let moved = schedule.lastMoved {
            let when = last.formatted(date: .abbreviated, time: .shortened)
            return moved > 0
                ? String(localized: "Last run \(when): \(moved) items sorted.")
                : String(localized: "Last run \(when): nothing to sort.")
        }
        return nil
    }

    private var nextRunText: String {
        guard schedule.isEnabled else { return String(localized: "Switched off") }
        if schedule.isDue() { return String(localized: "Due now. It runs at the next check, within a minute.") }
        if let next = schedule.nextRun(after: schedule.lastRunAt ?? schedule.createdAt) {
            return String(localized: "Next run: \(next.formatted(date: .abbreviated, time: .shortened))")
        }
        return String(localized: "Switched off")
    }
}

/// A small round icon button that shows a soft circle when the pointer is over it.
private struct CardIconButton: View {
    let symbol: String
    let help: LocalizedStringKey
    var isDestructive = false
    var isDisabled = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? (isDestructive ? Color.red : Color.primary) : Color.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.primary.opacity(hovering ? 0.1 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Adding and editing

struct ScheduleEditor: View {
    @State var schedule: Schedule
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current
    private let cardColumns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    init(schedule: Schedule) {
        _schedule = State(initialValue: schedule)
    }

    private var allowed: Set<FileCategory> { schedule.policy.allowedCategories }
    private var canSave: Bool { schedule.rootURL != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    folderSection
                    typesSection
                    whenSection
                    summary
                }
                .padding(24)
            }

            Divider()
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    model.save(schedule)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 560, height: 680)
    }

    // MARK: Folder

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Folder").font(.headline)
            LazyVGrid(columns: cardColumns, spacing: 10) {
                ForEach(LocationKind.allCases) { kind in
                    let isCustom = kind == .custom
                    let chosen = isCustom && schedule.customPath != nil
                    ChoiceCard(
                        symbol: kind.symbol,
                        title: chosen ? URL(fileURLWithPath: schedule.customPath ?? "").lastPathComponent : kind.title,
                        summary: chosen ? ((schedule.customPath ?? "") as NSString).abbreviatingWithTildeInPath : kind.summary,
                        isSelected: schedule.location == kind,
                        showsChange: chosen && schedule.location == kind
                    ) {
                        if isCustom {
                            chooseFolder()
                        } else {
                            schedule.location = kind
                            schedule.categories = schedule.categories.intersection(schedule.policy.allowedCategories)
                        }
                    }
                }
            }
        }
    }

    // MARK: Types

    private var typesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to sort").font(.headline)
            Picker("Types", selection: Binding(
                get: { schedule.categories.isEmpty },
                set: { all in
                    if all {
                        schedule.categories = []
                    } else if schedule.categories.isEmpty {
                        schedule.categories = [allowed.contains(.images) ? .images : (allowed.first ?? .images)]
                    }
                }
            )) {
                Text("Everything").tag(true)
                Text("Selective").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if !schedule.categories.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(FileCategory.allCases, id: \.self) { category in
                        CategoryChip(title: category.displayName, symbol: category.symbol,
                                     isOn: schedule.categories.contains(category),
                                     isEnabled: allowed.contains(category)) {
                            toggle(category)
                        }
                    }
                }
            }
        }
    }

    // MARK: When

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("When").font(.headline)

            Picker("Repeat", selection: $schedule.frequency) {
                ForEach(ScheduleFrequency.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch schedule.frequency {
            case .daily:
                EmptyView()
            case .weekly:
                weekdayRow
            case .monthly:
                monthGrid
            }

            timeRow
        }
        .animation(.easeOut(duration: 0.18), value: schedule.frequency)
    }

    /// Seven round buttons, like the repeat days of an alarm, starting on the week's first day.
    private var weekdayRow: some View {
        let letters = calendar.veryShortWeekdaySymbols
        let names = calendar.weekdaySymbols
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 }
        return HStack(spacing: 8) {
            ForEach(order, id: \.self) { index in
                DayDot(label: letters[index], isOn: schedule.weekday == index + 1, accessibilityName: names[index]) {
                    schedule.weekday = index + 1
                }
            }
        }
    }

    /// Days 1–28 in a small grid. 29–31 aren't offered, so every month has the day.
    private var monthGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 8), count: 7), alignment: .leading, spacing: 8) {
                ForEach(1...28, id: \.self) { day in
                    DayDot(label: "\(day)", isOn: schedule.dayOfMonth == day, accessibilityName: "\(day)") {
                        schedule.dayOfMonth = day
                    }
                }
            }
            Text("Days 29–31 aren’t offered, so every month has the day.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Time")
                .font(.callout)
                .foregroundStyle(.secondary)
            TimeWheel(hour: $schedule.hour, minute: $schedule.minute)
                .padding(.horizontal, 6)
                .cardBackground(cornerRadius: 14)
        }
    }

    // MARK: Summary

    private var summary: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.describe())
                    .font(.callout.weight(.semibold))
                if let next = schedule.nextRun(after: Date()) {
                    Text("Next run: \(next.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Files newer than ten minutes are left alone. Sottodesu has to be running, or kept in the menu bar, for a schedule to run.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    // MARK: Helpers

    private func toggle(_ category: FileCategory) {
        if schedule.categories.contains(category) {
            if schedule.categories.count > 1 { schedule.categories.remove(category) }
        } else {
            schedule.categories.insert(category)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a folder to sort")
        panel.prompt = String(localized: "Choose")
        guard panel.runModal() == .OK, let url = panel.url, FolderGuard.isAllowedCustomFolder(url) else { return }
        schedule.customPath = url.path
        schedule.location = .custom
        schedule.categories = schedule.categories.intersection(schedule.policy.allowedCategories)
    }
}

/// A round button for a weekday or a day of the month.
private struct DayDot: View {
    let label: String
    let isOn: Bool
    let accessibilityName: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(isOn ? Color.accentColor : Color.primary.opacity(hovering ? 0.12 : 0.06)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isOn)
        .accessibilityLabel(accessibilityName)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
