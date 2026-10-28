import SwiftUI

/// Shown above the window when a newer version exists.
struct UpdateBanner: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let release = model.foundRelease, !model.updateBannerHidden {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sottodesu \(release.tag) is available")
                        .font(.headline)
                    detail
                }
                Spacer(minLength: 8)
                if model.updateState == .installing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Release Notes") { openURL(release.pageURL) }
                        .buttonStyle(.link)
                    Button("Skip This Version") { model.skipFoundRelease() }
                        .buttonStyle(.link)
                    Button("Later") { model.hideUpdateBanner() }
                    Button("Update and Relaunch") { model.installUpdate() }
                        .buttonStyle(.borderedProminent)
                        .disabled(release.dmgURL == nil)
                }
            }
            .padding(14)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Divider() }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.updateState {
        case .installing:
            Text("Downloading and installing…")
                .font(.callout).foregroundStyle(.secondary)
        case .failed(let message):
            HStack(spacing: 6) {
                Text(message).font(.callout).foregroundStyle(.red)
                if let release = model.foundRelease {
                    Button("Download Page") { openURL(release.pageURL) }
                        .buttonStyle(.link).font(.callout)
                }
            }
        default:
            Text("You have \(UpdateService.currentVersion?.description ?? "?"). Sottodesu will restart to finish the update.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

/// Sottodesu ▸ Settings (⌘,).
struct UpdateSettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { model.updateChecksEnabled }, set: { model.setUpdateChecks($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Check for updates automatically")
                    Text("About once a day Sottodesu asks GitHub for the number of the latest release. Nothing about you or your files is sent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            Divider()
            HStack {
                status
                Spacer()
                Button("Check Now") { model.checkForUpdates(userInitiated: true) }
                    .disabled(model.updateState == .checking || model.updateState == .installing)
            }
            if model.foundRelease != nil {
                Button("Update and Relaunch") { model.installUpdate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.updateState == .installing)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    @ViewBuilder
    private var status: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Version \(UpdateService.currentVersion?.description ?? "?")")
                .font(.callout.weight(.medium))
            switch model.updateState {
            case .checking:
                Text("Checking…").font(.caption).foregroundStyle(.secondary)
            case .installing:
                Text("Downloading and installing…").font(.caption).foregroundStyle(.secondary)
            case .failed(let message):
                Text(message).font(.caption).foregroundStyle(.red)
            default:
                if let release = model.foundRelease {
                    Text("Sottodesu \(release.tag) is available").font(.caption).foregroundStyle(Color.accentColor)
                } else if let last = model.lastUpdateCheck {
                    Text("Up to date · checked \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
