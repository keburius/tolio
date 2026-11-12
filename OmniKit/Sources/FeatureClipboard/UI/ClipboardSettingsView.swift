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
            Picker("Keep up to", selection: settings.binding(ClipboardHistoryFeature.maxItemsKey)) {
                ForEach([100, 500, 1000, 5000], id: \.self) { Text("\($0) items").tag($0) }
            }
            .onChange(of: settings.value(ClipboardHistoryFeature.maxItemsKey)) { feature.prune() }
            Picker("Delete items older than", selection: settings.binding(ClipboardHistoryFeature.maxAgeDaysKey)) {
                Text("1 day").tag(1)
                Text("1 week").tag(7)
                Text("1 month").tag(30)
                Text("3 months").tag(90)
                Text("1 year").tag(365)
                Text("Never").tag(0)
            }
            .onChange(of: settings.value(ClipboardHistoryFeature.maxAgeDaysKey)) { feature.prune() }
            Text("Pinned items are never deleted automatically. Items marked secret by password managers are never stored.")
                .font(.caption).foregroundStyle(.secondary)

            ExcludedAppsEditor(settings: settings)

            Section("History") {
                TextField("Search history", text: $query)
                let records = feature.records(matching: query, limit: 200)
                if records.isEmpty {
                    Text(query.isEmpty ? "Nothing copied yet." : "No matches.").foregroundStyle(.secondary)
                }
                ForEach(records) { record in
                    HistoryRow(feature: feature, record: record)
                }
                Button("Clear History…", role: .destructive) { confirmClear = true }
                    .confirmationDialog("Clear clipboard history?", isPresented: $confirmClear) {
                        Button("Clear, Keep Pinned") { feature.clear(keepPinned: true) }
                        Button("Clear Everything", role: .destructive) { feature.clear(keepPinned: false) }
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
            VStack(alignment: .leading, spacing: 2) {
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
            .help(record.pinned ? "Unpin" : "Pin")
            Button { feature.copy(record) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless).help("Copy")
            Button { feature.delete(record) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("Delete")
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
        Section("Never record copies from") {
            ForEach(ClipCapturePolicy.builtInExcludedApps.sorted().compactMap(installedApp), id: \.bundleID) { app in
                AppRow(app: app, note: "Password manager, always excluded")
            }
            let excluded = settings.value(ClipboardHistoryFeature.excludedAppsKey)
            ForEach(excluded.sorted(), id: \.self) { bundleID in
                HStack {
                    AppRow(app: installedApp(bundleID) ?? AppInfo(bundleID: bundleID, name: bundleID, url: nil), note: nil)
                    Spacer()
                    Button("Remove") {
                        settings.set(excluded.subtracting([bundleID]), for: ClipboardHistoryFeature.excludedAppsKey)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Menu("Add App") {
                ForEach(runningApps(excluding: excluded), id: \.bundleID) { app in
                    Button(app.name) {
                        settings.set(excluded.union([app.bundleID]), for: ClipboardHistoryFeature.excludedAppsKey)
                    }
                }
            }
            .fixedSize()
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
