import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Retention, exclusions, and a browsable history with pin and delete.
struct ClipboardSettingsView: View {
    let feature: ClipboardHistoryFeature
    let settings: SettingsStore
    @State private var query = ""
    @State private var confirmClear = false

    var body: some View {
        Group {
            Picker(L10n.Clipboard.keepUpTo, selection: settings.binding(ClipboardHistoryFeature.maxItemsKey)) {
                ForEach([100, 500, 1000, 5000], id: \.self) { Text(L10n.Clipboard.itemCount($0)).tag($0) }
            }
            .onChange(of: settings.value(ClipboardHistoryFeature.maxItemsKey)) { feature.prune() }
            .settingsAnchor(ClipboardHistoryFeature.Anchor.keepUpTo)
            Picker(L10n.Clipboard.deleteOlderThan, selection: settings.binding(ClipboardHistoryFeature.maxAgeDaysKey)) {
                Text(L10n.Clipboard.oneDay).tag(1)
                Text(L10n.Clipboard.oneWeek).tag(7)
                Text(L10n.Clipboard.oneMonth).tag(30)
                Text(L10n.Clipboard.threeMonths).tag(90)
                Text(L10n.Clipboard.oneYear).tag(365)
                Text(L10n.Clipboard.never).tag(0)
            }
            .onChange(of: settings.value(ClipboardHistoryFeature.maxAgeDaysKey)) { feature.prune() }
            .settingsAnchor(ClipboardHistoryFeature.Anchor.maxAge)
            Text(L10n.Clipboard.retentionNote)
                .font(.caption).foregroundStyle(.secondary)

            ExcludedAppsEditor(settings: settings)

            Section(L10n.Clipboard.history) {
                TextField(L10n.Clipboard.searchHistory, text: $query)
                    .settingsAnchor(ClipboardHistoryFeature.Anchor.history)
                let records = feature.records(matching: query, limit: 200)
                if records.isEmpty {
                    if query.isEmpty {
                        EmptyState(symbol: "doc.on.clipboard", message: L10n.Clipboard.emptyHistory)
                    } else {
                        Text(L10n.Common.noMatches(query)).foregroundStyle(.secondary)
                    }
                }
                ForEach(records) { record in
                    HistoryRow(feature: feature, record: record)
                }
                Button(L10n.Clipboard.clearHistory, role: .destructive) { confirmClear = true }
                    .settingsAnchor(ClipboardHistoryFeature.Anchor.clear)
                    .confirmationDialog(L10n.Clipboard.clearQuestion, isPresented: $confirmClear) {
                        Button(L10n.Clipboard.clearKeepPinned) { feature.clear(keepPinned: true) }
                        Button(L10n.Clipboard.clearEverything, role: .destructive) { feature.clear(keepPinned: false) }
                    }
            }
        }
    }
}

private struct HistoryRow: View {
    let feature: ClipboardHistoryFeature
    let record: ClipRecord

    var body: some View {
        HStack {
            preview.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: OmniStyle.s1) {
                Text(record.title).lineLimit(1)
                Text([record.sourceAppName, record.createdAt.formatted(date: .abbreviated, time: .shortened)]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { feature.setPinned(!record.pinned, record) } label: {
                Image(systemName: record.pinned ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(record.pinned ? L10n.Clipboard.unpin : L10n.Clipboard.pin)
            .accessibilityLabel(record.pinned ? L10n.Clipboard.unpin : L10n.Clipboard.pin)
            Button { feature.copy(record) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless).help(L10n.Clipboard.copy)
                .accessibilityLabel(L10n.Clipboard.copy)
            Button { feature.delete(record) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).help(L10n.Clipboard.delete)
                .accessibilityLabel(L10n.Clipboard.delete)
        }
    }

    @ViewBuilder private var preview: some View {
        switch record.kind {
        case .text:
            Image(systemName: "text.alignleft").foregroundStyle(.secondary)
        case .image:
            if let url = feature.store?.thumbnailURL(for: record), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo")
            }
        case .files:
            if let url = record.fileURLs.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
            }
        }
    }
}

/// The user's list of apps whose copies are never recorded.
private struct ExcludedAppsEditor: View {
    let settings: SettingsStore

    var body: some View {
        Section(L10n.Clipboard.neverRecordFrom) {
            ForEach(ClipCapturePolicy.builtInExcludedApps.sorted().compactMap(installedApp), id: \.bundleID) { app in
                AppRow(app: app, note: L10n.Clipboard.passwordManagerNote)
            }
            let excluded = settings.value(ClipboardHistoryFeature.excludedAppsKey)
            if excluded.isEmpty {
                EmptyState(symbol: "app.dashed", message: L10n.Common.noAppsExcluded)
            }
            ForEach(excluded.sorted(), id: \.self) { bundleID in
                HStack {
                    AppRow(app: installedApp(bundleID) ?? AppInfo(bundleID: bundleID, name: bundleID, url: nil), note: nil)
                    Spacer()
                    Button(L10n.Common.remove) {
                        settings.set(excluded.subtracting([bundleID]), for: ClipboardHistoryFeature.excludedAppsKey)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Menu(L10n.Common.addApp) {
                ForEach(runningApps(excluding: excluded), id: \.bundleID) { app in
                    Button(app.name) {
                        settings.set(excluded.union([app.bundleID]), for: ClipboardHistoryFeature.excludedAppsKey)
                    }
                }
            }
            .fixedSize()
            .settingsAnchor(ClipboardHistoryFeature.Anchor.excludedApps)
        }
    }

    private func installedApp(_ bundleID: String) -> AppInfo? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return AppInfo(bundleID: bundleID, name: FileManager.default.displayName(atPath: url.path), url: url)
    }

    private func runningApps(excluding excluded: Set<String>) -> [AppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> AppInfo? in
                guard let id = app.bundleIdentifier, !excluded.contains(id),
                      !ClipCapturePolicy.builtInExcludedApps.contains(id) else { return nil }
                return AppInfo(bundleID: id, name: app.localizedName ?? id, url: app.bundleURL)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct AppInfo {
    let bundleID: String
    let name: String
    let url: URL?
}

private struct AppRow: View {
    let app: AppInfo
    let note: String?

    var body: some View {
        HStack {
            if let url = app.url {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 20, height: 20)
            }
            VStack(alignment: .leading) {
                Text(app.name)
                if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}
