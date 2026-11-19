import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Retention and exclusions side by side, then a browsable history with
/// pin, copy and delete.
struct ClipboardSettingsView: View {
    let feature: ClipboardHistoryFeature
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                retention.frame(maxWidth: .infinity, alignment: .leading)
                ExcludedAppsEditor(settings: settings).frame(maxWidth: .infinity, alignment: .leading)
            }
            HistoryBrowser(feature: feature)
        }
    }

    private var retention: some View {
        ASSection(L10n.Clipboard.history, footer: L10n.Clipboard.retentionNote) {
            ASRow(L10n.Clipboard.keepUpTo) {
                ASPopUp(
                    L10n.Clipboard.keepUpTo, selection: settings.binding(ClipboardHistoryFeature.maxItemsKey),
                    options: [100, 500, 1000, 5000].map { ($0, L10n.Clipboard.itemCount($0)) }
                )
            }
            .onChange(of: settings.value(ClipboardHistoryFeature.maxItemsKey)) { feature.prune() }
            .settingsAnchor(ClipboardHistoryFeature.Anchor.keepUpTo)
            ASRow(L10n.Clipboard.deleteOlderThan) {
                ASPopUp(
                    L10n.Clipboard.deleteOlderThan, selection: settings.binding(ClipboardHistoryFeature.maxAgeDaysKey),
                    options: [
                        (1, L10n.Clipboard.oneDay), (7, L10n.Clipboard.oneWeek), (30, L10n.Clipboard.oneMonth),
                        (90, L10n.Clipboard.threeMonths), (365, L10n.Clipboard.oneYear), (0, L10n.Clipboard.never),
                    ]
                )
            }
            .onChange(of: settings.value(ClipboardHistoryFeature.maxAgeDaysKey)) { feature.prune() }
            .settingsAnchor(ClipboardHistoryFeature.Anchor.maxAge)
        }
    }
}

// MARK: - History

/// Search the whole history; pin, copy or delete items; clear it.
private struct HistoryBrowser: View {
    let feature: ClipboardHistoryFeature
    @State private var query = ""
    @State private var confirmClear = false

    var body: some View {
        let records = feature.records(matching: query, limit: 200)
        VStack(alignment: .leading, spacing: 6) {
            ASSectionTitle(L10n.Clipboard.copiedItems)
            ASCard {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        SearchField(text: $query, prompt: L10n.Clipboard.searchHistory)
                            .settingsAnchor(ClipboardHistoryFeature.Anchor.history)
                        Button(L10n.Clipboard.clearHistory) { confirmClear = true }
                            .buttonStyle(.asDestructive)
                            .settingsAnchor(ClipboardHistoryFeature.Anchor.clear)
                            .confirmationDialog(L10n.Clipboard.clearQuestion, isPresented: $confirmClear) {
                                Button(L10n.Clipboard.clearKeepPinned) { feature.clear(keepPinned: true) }
                                Button(L10n.Clipboard.clearEverything, role: .destructive) { feature.clear(keepPinned: false) }
                            }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    Rectangle().fill(AS.divider).frame(height: 1)
                    if records.isEmpty {
                        Text(query.isEmpty ? L10n.Clipboard.emptyHistory : L10n.Common.noMatches(query))
                            .font(AS.body).foregroundStyle(AS.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 12)
                    } else {
                        ScrollView {
                            ASDividedStack {
                                ForEach(records) { HistoryRow(feature: feature, record: $0) }
                            }
                        }
                        .frame(maxHeight: 312)
                        .fixedSize(horizontal: false, vertical: records.count <= 6)
                    }
                }
            }
        }
    }
}

/// A rounded search box in the All Set look.
private struct SearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 6) {
            LineIcon(ASIcon.search, size: 13, color: AS.textSecondary)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(AS.textTertiary))
                .textFieldStyle(.plain)
                .font(AS.body)
                .foregroundStyle(AS.text)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).fill(AS.fieldFill))
    }
}

private enum Icons {
    static let copy = "M5.500 4.500h6.500v8.500H5.500zM3.500 11V2.500h6"
    static let trash = "M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.7 8.5h5.6l.7-8.5"
    static let text = "M3 4h10M3 8h10M3 12h6"
    static let files = "M4 2.5h5l3 3v8H4zM9 2.5v3h3"
}

private struct HistoryRow: View {
    let feature: ClipboardHistoryFeature
    let record: ClipRecord

    var body: some View {
        HStack(spacing: 10) {
            preview
                .frame(width: 27, height: 27)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(AS.controlFill))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(record.title).font(AS.font(12.5, .medium)).foregroundStyle(AS.text).lineLimit(1).truncationMode(.tail)
                Text([record.sourceAppName, record.createdAt.formatted(date: .abbreviated, time: .shortened)]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(AS.font(11)).foregroundStyle(AS.textTertiary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            iconButton(ASIcon.pin, label: record.pinned ? L10n.Clipboard.unpin : L10n.Clipboard.pin,
                       color: record.pinned ? AS.blue : AS.textSecondary) {
                feature.setPinned(!record.pinned, record)
            }
            iconButton(Icons.copy, label: L10n.Clipboard.copy) { feature.copy(record) }
            iconButton(Icons.trash, label: L10n.Clipboard.delete) { feature.delete(record) }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
    }

    private func iconButton(_ data: String, label: String, color: Color = AS.textSecondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LineIcon(data, size: 14, color: color)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var preview: some View {
        switch record.kind {
        case .text:
            LineIcon(Icons.text, size: 14, color: AS.icon)
        case .image:
            if let url = feature.store?.thumbnailURL(for: record), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                LineIcon(ASIcon.picture, size: 14, color: AS.icon)
            }
        case .files:
            if let url = record.fileURLs.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().padding(2)
            } else {
                LineIcon(Icons.files, size: 14, color: AS.icon)
            }
        }
    }
}

// MARK: - Excluded apps

/// The user's list of apps whose copies are never recorded.
private struct ExcludedAppsEditor: View {
    let settings: SettingsStore

    var body: some View {
        let excluded = settings.value(ClipboardHistoryFeature.excludedAppsKey)
        ASSection(L10n.Clipboard.neverRecordFrom) {
            ForEach(ClipCapturePolicy.builtInExcludedApps.sorted().compactMap(installedApp), id: \.bundleID) { app in
                ASRow(app.name, subtitle: L10n.Clipboard.passwordManagerNote) {
                    LineIconTile(ASIcon.key, size: 28, iconSize: 16)
                } trailing: {
                    EmptyView()
                }
            }
            ForEach(excluded.sorted(), id: \.self) { bundleID in
                let app = installedApp(bundleID) ?? AppInfo(bundleID: bundleID, name: bundleID, url: nil)
                ASRow(app.name) {
                    AppIcon(url: app.url)
                } trailing: {
                    Button(L10n.Common.remove) {
                        settings.set(excluded.subtracting([bundleID]), for: ClipboardHistoryFeature.excludedAppsKey)
                    }
                    .buttonStyle(.asSecondary)
                }
            }
            HStack {
                Text(excluded.isEmpty ? L10n.Clipboard.noOtherAppsExcluded : "")
                    .font(AS.font(12)).foregroundStyle(AS.textTertiary)
                Spacer()
                Menu {
                    ForEach(runningApps(excluding: excluded), id: \.bundleID) { app in
                        Button(app.name) {
                            settings.set(excluded.union([app.bundleID]), for: ClipboardHistoryFeature.excludedAppsKey)
                        }
                    }
                } label: {
                    ASPopUpLabel(L10n.Common.addApp)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .settingsAnchor(ClipboardHistoryFeature.Anchor.excludedApps)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
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

/// An app's own icon at row-icon size, or an empty glass tile.
private struct AppIcon: View {
    let url: URL?

    var body: some View {
        if let url {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 28, height: 28)
        } else {
            GlassTile(size: 28) { EmptyView() }
        }
    }
}
