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
        return Label(text, systemImage: model.showsMenuBarIcon ? "checkmark.circle" : "exclamationmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
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
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(schedule.lastError == nil ? Color.secondary : Color.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button("Run Now") { model.runNow(schedule) }
                    .disabled(!model.canWork || schedule.rootURL == nil)
                Button("Edit…", action: edit)
                Divider()
                Button("Delete", role: .destructive) { confirmDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Toggle("Enabled", isOn: Binding(get: { schedule.isEnabled },
                                            set: { model.setEnabled($0, for: schedule) }))
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(14)
        .cardBackground()
        .opacity(schedule.isEnabled ? 1 : 0.6)
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

    private var statusText: String {
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
        if schedule.isEnabled, let next = schedule.nextRun(after: Date()) {
            return String(localized: "Next run: \(next.formatted(date: .abbreviated, time: .shortened))")
        }
        return String(localized: "Switched off")
    }
}

// MARK: - Adding and editing

struct ScheduleEditor: View {
    @State var schedule: Schedule
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    init(schedule: Schedule) {
        _schedule = State(initialValue: schedule)
    }

    private var allowed: Set<FileCategory> { schedule.policy.allowedCategories }
    private var canSave: Bool { schedule.rootURL != nil }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Folder") {
                    Picker("Folder", selection: locationBinding) {
                        Text(LocationKind.downloads.title).tag(LocationKind.downloads)
                        Text(LocationKind.desktop.title).tag(LocationKind.desktop)
                        Text(LocationKind.home.title).tag(LocationKind.home)
                        Text(customTitle).tag(LocationKind.custom)
                    }
                    if schedule.location == .custom {
                        HStack {
                            Text(((schedule.customPath ?? "") as NSString).abbreviatingWithTildeInPath)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Choose…") { chooseFolder() }
                        }
                    }
                }

                Section("What to sort") {
                    Picker("Types", selection: Binding(get: { schedule.categories.isEmpty },
                                                       set: { all in if all { schedule.categories = [] } else if schedule.categories.isEmpty { schedule.categories = [allowed.first ?? .images] } })) {
                        Text("Everything").tag(true)
                        Text("Selective").tag(false)
                    }
                    .pickerStyle(.segmented)

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
                        .padding(.vertical, 4)
                    }
                }

                Section("How often") {
                    Picker("Repeat", selection: $schedule.frequency) {
                        ForEach(ScheduleFrequency.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if schedule.frequency == .weekly {
                        Picker("Day", selection: $schedule.weekday) {
                            ForEach(1...7, id: \.self) { day in
                                Text(calendar.weekdaySymbols[day - 1]).tag(day)
                            }
                        }
                    }
                    if schedule.frequency == .monthly {
                        Picker("Day of the month", selection: $schedule.dayOfMonth) {
                            ForEach(1...28, id: \.self) { Text("\($0)").tag($0) }
                        }
                    }
                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                }

                Section {
                    Text("Files newer than ten minutes are left alone, so something you just downloaded isn’t moved. Your Mac catches up on a missed run when it wakes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

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
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 520, height: 600)
    }

    private var customTitle: String {
        if let path = schedule.customPath { return URL(fileURLWithPath: path).lastPathComponent }
        return LocationKind.custom.title
    }

    private var locationBinding: Binding<LocationKind> {
        Binding(get: { schedule.location }, set: { kind in
            schedule.location = kind
            schedule.categories = schedule.categories.intersection(schedule.policy.allowedCategories)
            if kind == .custom && schedule.customPath == nil { chooseFolder() }
        })
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { calendar.date(bySettingHour: schedule.hour, minute: schedule.minute, second: 0, of: Date()) ?? Date() },
            set: {
                let parts = calendar.dateComponents([.hour, .minute], from: $0)
                schedule.hour = parts.hour ?? 0
                schedule.minute = parts.minute ?? 0
            }
        )
    }

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
        guard panel.runModal() == .OK, let url = panel.url else {
            if schedule.customPath == nil { schedule.location = .downloads }
            return
        }
        guard FolderGuard.isAllowedCustomFolder(url) else {
            if schedule.customPath == nil { schedule.location = .downloads }
            return
        }
        schedule.customPath = url.path
    }
}
