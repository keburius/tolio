import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Snap windows to halves, thirds, quarters; maximize, center, move between
/// displays, restore; optional drag-to-edge snapping.
@MainActor
@Observable
public final class WindowsFeature: Feature {
    static let gapKey = SettingKey.feature("windows", "gap", default: 0)
    static let dragSnapKey = SettingKey.feature("windows", "dragToEdge", default: false)

    public let id: FeatureID = "windows"
    public let displayName = "Window Management"
    public let summary = "Snap windows to halves, thirds, and quarters, move them between displays, and restore them."
    public let symbolName = "rectangle.split.2x1"
    public let requiredPermissions: Set<Permission> = [.accessibility]

    private(set) var dragError: String?
    @ObservationIgnored private var manager: WindowManager?
    @ObservationIgnored private var snapper: DragSnapper?
    @ObservationIgnored private var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let manager = WindowManager { CGFloat(settings.value(Self.gapKey)) }
        self.manager = manager

        for action in WindowAction.allCases {
            context.registerHotkey(HotkeyAction(id: "windows.\(action.rawValue)", title: action.title, defaultCombo: action.defaultCombo)) {
                manager.perform(action)
            }
            context.registerCommand(Command(
                id: "windows.\(action.rawValue)", title: action.title, subtitle: "Window",
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
                dragError = String(describing: error)
            }
        } else {
            snapper?.stop()
            snapper = nil
            dragError = nil
        }
    }
}

struct WindowsSettingsView: View {
    let feature: WindowsFeature
    let settings: SettingsStore

    var body: some View {
        Picker("Gap between windows", selection: settings.binding(WindowsFeature.gapKey)) {
            ForEach([0, 4, 8, 12, 16, 24], id: \.self) { Text($0 == 0 ? "None" : "\($0) pt").tag($0) }
        }
        Toggle("Snap by dragging a window to a screen edge", isOn: Binding(
            get: { settings.value(WindowsFeature.dragSnapKey) },
            set: {
                settings.set($0, for: WindowsFeature.dragSnapKey)
                feature.updateDragSnapping()
            }
        ))
        Text("Edges snap to halves, corners to quarters, the top edge maximizes. Edges shared with another display don't snap.")
            .font(.caption).foregroundStyle(.secondary)
        if let error = feature.dragError {
            Text(error).font(.caption).foregroundStyle(.red)
        }
        Text("Shortcuts are under Shortcuts; every action is also in the palette.")
            .font(.caption).foregroundStyle(.secondary)
    }
}
