import AppKit
import FinderSync
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Glass sticky notes on the desktop. Add one by right-clicking the desktop
/// (Omni's Finder extension), with ⌃⌥⌘N, the menu bar icon, or the Launcher.
@MainActor
@Observable
public final class StickyNotesFeature: Feature {
    static let tintKey = SettingKey.feature("stickynotes", "defaultTint", default: NoteTint.yellow)
    static let allSpacesKey = SettingKey.feature("stickynotes", "allSpaces", default: true)

    /// ⌃⌥⌘N
    public static let newHotkey = HotkeyAction(
        id: "stickynotes.new", title: L10n.StickyNotes.hotkeyNew,
        defaultCombo: KeyCombo(keyCode: 45, modifiers: [.control, .option, .command])
    )

    enum Anchor {
        static let tint = "stickynotes.tint"
        static let allSpaces = "stickynotes.allSpaces"
        static let finder = "stickynotes.finder"
    }

    public let id: FeatureID = "stickynotes"
    public var displayName: String { L10n.StickyNotes.displayName }
    public var summary: String { L10n.StickyNotes.summary }
    public let symbolName = "note.text"
    public let requiredPermissions: Set<Permission> = []

    @ObservationIgnored private var settings: SettingsStore?
    @ObservationIgnored private(set) var store: NoteStore?
    @ObservationIgnored private var windows: [UUID: NoteWindow] = [:]
    /// Bumped when notes are added or removed, so menus and Settings refresh.
    private(set) var revision = 0
    /// "Bring Notes to Front" until it's turned off again.
    private(set) var raised = false

    public init() {}

    public var declaredHotkeys: [HotkeyAction] { [Self.newHotkey] }

    public var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.tint, label: L10n.StickyNotes.defaultColor, keywords: ["color", "tint"]),
            SettingsEntry(anchor: Anchor.allSpaces, label: L10n.StickyNotes.allSpaces, keywords: ["desktop", "spaces"]),
            SettingsEntry(anchor: Anchor.finder, label: L10n.StickyNotes.rightClickTitle, keywords: ["right click", "finder", "desktop", "context menu"]),
        ]
    }

    public var erasableDataDescription: String? {
        _ = revision
        guard let store, !(store.notes.isEmpty && store.recentlyDeleted.isEmpty) else { return nil }
        return L10n.StickyNotes.eraseDescription(store.notes.count)
    }

    public func eraseData() {
        for window in windows.values { window.close() }
        windows.removeAll()
        store?.eraseAll()
        revision += 1
    }

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let store = NoteStore(url: try AppPaths.applicationSupport().appendingPathComponent("notes.json"))
        self.store = store
        for note in store.notes { open(note) }
        context.lifetime.add { [weak self] in self?.closeAll() }
        context.registerHotkey(Self.newHotkey) { [weak self] in self?.newNote(at: nil) }
        context.registerCommand(Command(
            id: "stickynotes.new", title: L10n.StickyNotes.newNote, keywords: ["sticky", "note", "memo", "post-it"], symbolName: symbolName
        ) { [weak self] in self?.newNote(at: nil) })
        context.registerCommand(Command(
            id: "stickynotes.front", title: L10n.StickyNotes.bringToFront, keywords: ["sticky", "notes", "show"], symbolName: "rectangle.stack"
        ) { [weak self] in self?.toggleRaised() })
    }

    public func disable() {
        settings = nil
        store = nil
    }

    private func closeAll() {
        for window in windows.values { window.close() }
        windows.removeAll()
        raised = false
    }

    // MARK: - Notes

    /// Creates a note with its top-left at `point` (AppKit global), or near the pointer.
    public func newNote(at point: CGPoint?) {
        guard let store, let settings else { return }
        let anchor = point ?? CGPoint(x: NSEvent.mouseLocation.x - 30, y: NSEvent.mouseLocation.y + 14)
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main ?? NSScreen.screens[0]
        var frame = NotePlacement.frame(at: anchor, in: screen.visibleFrame)
        frame = NotePlacement.cascade(frame, avoiding: store.notes.map(\.frame), in: screen.visibleFrame)
        let note = StickyNote(frame: frame, tint: settings.value(Self.tintKey))
        store.add(note)
        revision += 1
        open(note)?.focus()
    }

    @discardableResult
    private func open(_ note: StickyNote) -> NoteWindow? {
        guard let settings else { return nil }
        var note = note
        let screens = NSScreen.screens.map(\.visibleFrame)
        note.frame = NotePlacement.restore(note.frame, screens: screens, fallback: NSScreen.main?.visibleFrame ?? screens.first ?? .zero)
        let window = NoteWindow(note: note, allSpaces: settings.value(Self.allSpacesKey), actions: actions) { [weak self] updated in
            self?.store?.update(updated)
        }
        windows[note.id] = window
        window.apply(allSpaces: settings.value(Self.allSpacesKey), raised: raised)
        window.show()
        return window
    }

    private var actions: NoteActions {
        NoteActions(
            newNote: { [weak self] in self?.newNote(at: nil) },
            delete: { [weak self] id in self?.delete(id) },
            setTint: { [weak self] id, tint in self?.change(id) { $0.tint = tint } },
            setKeepOnTop: { [weak self] id, on in self?.change(id) { $0.keepOnTop = on } }
        )
    }

    private func change(_ id: UUID, _ body: (inout StickyNote) -> Void) {
        guard let window = windows[id], let settings else { return }
        body(&window.model.note)
        window.flush()
        window.apply(allSpaces: settings.value(Self.allSpacesKey), raised: raised)
    }

    /// Deletes a note; it can be brought back with "Restore Deleted Note".
    func delete(_ id: UUID) {
        guard let window = windows.removeValue(forKey: id) else { return }
        window.flush()
        let hadText = !window.model.note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        window.close()
        store?.delete(id)
        revision += 1
        if hadText {
            ActionToast.show(L10n.StickyNotes.deleted, symbol: "trash", actionTitle: L10n.StickyNotes.undo) { [weak self] in
                self?.restoreDeleted()
            }
        }
    }

    func restoreDeleted() {
        guard let note = store?.restoreLastDeleted() else { return }
        revision += 1
        open(note)?.focus()
    }

    func focus(_ id: UUID) {
        windows[id]?.focus()
    }

    /// Lifts every note above app windows until turned off again.
    func toggleRaised() {
        guard let settings else { return }
        raised.toggle()
        for window in windows.values {
            window.apply(allSpaces: settings.value(Self.allSpacesKey), raised: raised)
            window.show()
        }
    }

    func applyAllSpaces() {
        guard let settings else { return }
        for window in windows.values { window.apply(allSpaces: settings.value(Self.allSpacesKey), raised: raised) }
    }

    // MARK: - Finder extension

    /// Whether "New Sticky Note" is switched on in Finder's right-click menu.
    var finderExtensionEnabled: Bool { FIFinderSyncController.isExtensionEnabled }

    func openFinderExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    // MARK: - Menu bar icon

    public var quickAccessItems: [QuickAccessItem] {
        [QuickAccessItem(
            id: .stickyNotes, title: L10n.StickyNotes.displayName, symbolName: symbolName,
            clickHint: L10n.StickyNotes.clickHint, shortcutID: Self.newHotkey.id,
            primary: { [weak self] in self?.newNote(at: nil) },
            menu: { [weak self] in self?.menu() ?? [] }
        )]
    }

    func menu() -> [MenuEntry] {
        guard let store else { return [] }
        typealias S = L10n.StickyNotes
        var entries: [MenuEntry] = [
            .action(MenuAction(S.newNote, shortcutID: Self.newHotkey.id) { [weak self] in self?.newNote(at: nil) }),
            .action(MenuAction(S.bringToFront, isChecked: raised) { [weak self] in self?.toggleRaised() }),
        ]
        if !store.notes.isEmpty {
            entries.append(.separator)
            for note in store.notes.sorted(by: { $0.modified > $1.modified }).prefix(15) {
                let title = note.title.isEmpty ? S.untitled : String(note.title.prefix(40))
                entries.append(.action(MenuAction(title, icon: .symbol("note.text")) { [weak self] in self?.focus(note.id) }))
            }
        }
        entries.append(.separator)
        entries.append(.action(MenuAction(S.restoreDeleted, isEnabled: !store.recentlyDeleted.isEmpty) { [weak self] in self?.restoreDeleted() }))
        if !finderExtensionEnabled {
            entries.append(.action(MenuAction(S.enableRightClick) { [weak self] in self?.openFinderExtensionSettings() }))
        }
        return entries
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(StickyNotesSettingsView(feature: self, settings: settings))
    }
}

struct StickyNotesSettingsView: View {
    let feature: StickyNotesFeature
    let settings: SettingsStore
    @State private var finderEnabled = false
    private typealias S = L10n.StickyNotes

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(S.rightClickTitle)
                    Text(finderEnabled ? S.rightClickOn : S.rightClickOff).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !finderEnabled {
                    Button(L10n.Common.openSystemSettings) { feature.openFinderExtensionSettings() }
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel(L10n.Permissions.allowed)
                }
            }
            .settingsAnchor(StickyNotesFeature.Anchor.finder)
            Picker(S.defaultColor, selection: settings.binding(StickyNotesFeature.tintKey)) {
                ForEach(NoteTint.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            .settingsAnchor(StickyNotesFeature.Anchor.tint)
            Toggle(S.allSpaces, isOn: Binding(
                get: { settings.value(StickyNotesFeature.allSpacesKey) },
                set: { settings.set($0, for: StickyNotesFeature.allSpacesKey); feature.applyAllSpaces() }
            ))
            .settingsAnchor(StickyNotesFeature.Anchor.allSpaces)
            Text(S.settingsNote).font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { finderEnabled = feature.finderExtensionEnabled }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            finderEnabled = feature.finderExtensionEnabled
        }
    }
}
