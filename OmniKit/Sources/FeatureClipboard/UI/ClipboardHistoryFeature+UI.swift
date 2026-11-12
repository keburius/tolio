import Foundation
import OmniCore
import SwiftUI

/// What the app shows for Clipboard History: shortcuts, settings search,
/// reset/erase, and the menu bar icon with its menu. No new behaviour; every
/// action calls the feature's existing operations.
public extension ClipboardHistoryFeature {
    var declaredHotkeys: [HotkeyAction] { Self.hotkeys }

    var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.keepUpTo, label: L10n.Clipboard.keepUpTo, keywords: ["limit", "maximum", "size", "items"]),
            SettingsEntry(anchor: Anchor.maxAge, label: L10n.Clipboard.deleteOlderThan, keywords: ["retention", "age", "expire", "days"]),
            SettingsEntry(anchor: Anchor.excludedApps, label: L10n.Clipboard.neverRecordFrom, keywords: ["exclude", "ignore", "privacy", "password"]),
            SettingsEntry(anchor: Anchor.history, label: L10n.Clipboard.history, keywords: ["search", "browse", "pin", "items"]),
            SettingsEntry(anchor: Anchor.clear, label: L10n.Clipboard.clearHistory, keywords: ["delete", "wipe", "remove", "erase"]),
        ]
    }

    var userContentSettingKeys: Set<String> { [Self.excludedAppsKey.name] }

    var erasableDataDescription: String? {
        guard let store, let count = try? store.count(), count > 0 else { return nil }
        return L10n.Clipboard.eraseDescription(count)
    }

    func eraseData() {
        guard let store else { return }
        let count = (try? store.count()) ?? 0
        do {
            try store.deleteAll(keepPinned: false)
            context?.log.notice("Erased clipboard history (\(count, privacy: .public) items, including pinned)")
        } catch {
            context?.log.error("Could not erase clipboard history: \(String(describing: error), privacy: .public)")
        }
        prune()
    }

    var quickAccessItems: [QuickAccessItem] {
        [
            QuickAccessItem(
                id: .clipboard, title: L10n.Clipboard.quickTitle, symbolName: "doc.on.clipboard",
                clickHint: L10n.Clipboard.quickClickHint, shortcutID: Self.showHotkey.id,
                primary: { [weak self] in self?.showHistory() },
                menu: { [weak self] in self?.quickAccessMenu() ?? [] },
                clickPanel: { [weak self] close in
                    guard let self else { return AnyView(EmptyView()) }
                    return AnyView(ClipboardDropdown(feature: self, close: close))
                }
            ),
        ]
    }
}

extension ClipboardHistoryFeature {
    /// Settings anchors (`.settingsAnchor(_:)`) on the settings page.
    enum Anchor {
        static let keepUpTo = "clipboard.keepUpTo"
        static let maxAge = "clipboard.maxAge"
        static let excludedApps = "clipboard.excludedApps"
        static let history = "clipboard.history"
        static let clear = "clipboard.clear"
    }

    /// Items in the menu bar menu.
    static let menuItemCount = 5
    /// Characters of an item's title shown in the menu.
    static let menuTitleLength = 40

    /// Pastes into the frontmost app: what the Launcher, the control panel
    /// and the menu bar menu run for an item.
    func pasteAction(for record: ClipRecord) -> @MainActor @Sendable () -> Void {
        { [weak self] in self?.paste(record) }
    }

    /// The right-click menu of the Clipboard icon (DESIGN §1.2). The app
    /// appends "Clipboard History Settings…" and "Hide This Icon".
    func quickAccessMenu(now: Date = Date()) -> [MenuEntry] {
        var entries: [MenuEntry] = [
            .action(MenuAction(L10n.Clipboard.menuShowHistory, shortcutID: Self.showHotkey.id) { [weak self] in
                self?.showHistory()
            }),
            .separator,
        ]
        let recent = newestRecords(limit: Self.menuItemCount)
        if recent.isEmpty {
            entries.append(.header(L10n.Clipboard.emptyHistory))
        } else {
            for record in recent {
                let title = L10n.Clipboard.menuRecentItem(Self.oneLine(record.title), age: Self.age(of: record.createdAt, now: now))
                entries.append(.action(MenuAction(title, perform: pasteAction(for: record))))
            }
        }
        entries.append(.separator)
        let unpinned = (try? store?.unpinnedCount()) ?? 0
        entries.append(.action(MenuAction(
            L10n.Clipboard.menuClearHistory, isEnabled: unpinned > 0,
            confirmation: L10n.Clipboard.clearConfirmation(unpinned)
        ) { [weak self] in self?.clear(keepPinned: true) }))
        return entries
    }

    /// Items in the history list (left-click on the icon, ⌃⌥V).
    static let historyMenuCount = 40
    /// Characters of an item's first line shown in the history list.
    static let historyTitleLength = 60

    /// The history as a plain menu list: pinned items, then the newest
    /// copies. Choosing one pastes it into the frontmost app; the first nine
    /// also answer to ⌘1–⌘9.
    func historyMenu() -> [MenuEntry] {
        let recent = newestRecords(limit: Self.historyMenuCount)
        let pinned = recent.filter(\.pinned)
        let others = recent.filter { !$0.pinned }
        var entries: [MenuEntry] = []
        if recent.isEmpty {
            entries.append(.header(L10n.Clipboard.emptyHistory))
        }
        var digit = 1
        func item(_ record: ClipRecord) -> MenuEntry {
            defer { digit += 1 }
            let title = record.title.count > Self.historyTitleLength
                ? String(record.title.prefix(Self.historyTitleLength - 1)) + "…" : record.title
            let icon: SearchResult.Icon? = switch record.kind {
            case .text: record.sourceBundleID == PasteboardTypes.capturedTextSource ? .symbol("text.viewfinder") : nil
            case .image: store?.thumbnailURL(for: record).map { .image($0) } ?? .symbol("photo")
            case .files: record.fileURLs.first.map { .file($0) } ?? .symbol("doc")
            }
            let tip = record.kind == .text ? record.text.map { String($0.prefix(400)) } : nil
            return .action(MenuAction(
                title, icon: icon, commandDigit: digit <= 9 ? digit : nil, toolTip: tip, perform: pasteAction(for: record)
            ))
        }
        if !pinned.isEmpty {
            entries.append(.header(L10n.Clipboard.pinnedHeader))
            entries += pinned.map(item)
            if !others.isEmpty { entries.append(.separator) }
        }
        entries += others.map(item)
        entries.append(.separator)
        entries.append(.action(MenuAction(L10n.Clipboard.menuSearchHistory) { [weak self] in self?.searchHistory() }))
        let unpinned = (try? store?.unpinnedCount()) ?? 0
        entries.append(.action(MenuAction(
            L10n.Clipboard.menuClearHistory, isEnabled: unpinned > 0,
            confirmation: L10n.Clipboard.clearConfirmation(unpinned)
        ) { [weak self] in self?.clear(keepPinned: true) }))
        return entries
    }

    /// The title clipped for a menu line.
    static func oneLine(_ title: String) -> String {
        title.count > menuTitleLength ? String(title.prefix(menuTitleLength - 1)) + "…" : title
    }

    /// "now", "2m", "1h", "3d".
    static func age(of date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 60 else { return L10n.Clipboard.ageNow }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.minute, .hour, .day, .weekOfMonth]
        return formatter.string(from: seconds) ?? L10n.Clipboard.ageNow
    }
}
