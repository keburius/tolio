import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Window Layouts: snap windows to halves, thirds, quarters; maximize,
/// center, move between displays, restore; optional drag-to-edge snapping.
@MainActor
@Observable
public final class WindowsFeature: Feature {
    static let gapKey = SettingKey.feature("windows", "gap", default: 0)
    static let dragSnapKey = SettingKey.feature("windows", "dragToEdge", default: false)
    /// Gap sizes offered in Settings and the menu bar icon's menu, in points.
    static let gapChoices = [0, 4, 8, 12, 16, 24]

    /// One hotkey per layout, the same list `enable` registers.
    public static var hotkeys: [HotkeyAction] { WindowAction.allCases.map(\.hotkey) }

    enum Anchor {
        static let gap = "windows.gap"
        static let dragToEdge = "windows.dragToEdge"
    }

    public let id: FeatureID = "windows"
    public var displayName: String { L10n.Windows.displayName }
    public var summary: String { L10n.Windows.summary }
    public var tagline: String { L10n.Windows.tagline }
    public var settingsViewEditsShortcuts: Bool { true }
    public let symbolName = "rectangle.split.2x1"
    public let group: FeatureGroup = .windows
    public let requiredPermissions: Set<Permission> = [.accessibility]
    public var declaredHotkeys: [HotkeyAction] { Self.hotkeys }

    public var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.gap, label: L10n.Windows.gap, keywords: ["snap", "tile", "spacing", "margin", "padding"]),
            SettingsEntry(anchor: Anchor.dragToEdge, label: L10n.Windows.dragToEdge, keywords: ["snap", "tile", "drag", "edge", "corner"]),
        ]
    }

    private(set) var dragError: String?
    @ObservationIgnored private(set) var manager: WindowManager?
    @ObservationIgnored private var snapper: DragSnapper?
    @ObservationIgnored private(set) var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let manager = WindowManager { CGFloat(settings.value(Self.gapKey)) }
        self.manager = manager

        for action in WindowAction.allCases {
            context.registerHotkey(action.hotkey) {
                manager.perform(action)
            }
            context.registerCommand(Command(
                id: action.hotkeyID, title: action.title, subtitle: L10n.Windows.commandSubtitle,
                keywords: ["window", "snap", "move", "resize"], symbolName: action.symbolName
            ) { manager.perform(action) })
        }
        updateDragSnapping()
        context.lifetime.add { [weak self] in
            self?.snapper?.stop()
            self?.snapper = nil
        }
    }

    public func disable() {
        manager = nil
        settings = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(WindowsSettingsView(feature: self, settings: settings))
    }

    public func makeSettingsHero() -> AnyView? {
        AnyView(WindowsHero())
    }

    /// Starts or stops the drag listener to match the setting.
    func updateDragSnapping() {
        guard let manager, let settings else { return }
        if settings.value(Self.dragSnapKey) {
            guard snapper == nil else { return }
            let snapper = DragSnapper(manager: manager)
            do {
                try snapper.start()
                self.snapper = snapper
                dragError = nil
            } catch {
                dragError = L10n.Windows.dragToEdgeFailed
            }
        } else {
            snapper?.stop()
            snapper = nil
            dragError = nil
        }
    }

    /// Changes the drag-to-edge setting and starts or stops the listener.
    func setDragSnapping(_ isOn: Bool) {
        settings?.set(isOn, for: Self.dragSnapKey)
        updateDragSnapping()
    }

    /// "None" or "8 pt".
    static func gapTitle(_ points: Int) -> String {
        points == 0 ? L10n.Common.none : L10n.Windows.gapPoints(points)
    }
}
