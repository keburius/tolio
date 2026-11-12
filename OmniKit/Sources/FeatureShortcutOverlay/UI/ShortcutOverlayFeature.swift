import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Shows the frontmost app's keyboard shortcuts, read from its menu bar.
@MainActor
@Observable
public final class ShortcutOverlayFeature: Feature {
    static let triggerKey = SettingKey.feature("shortcuts", "trigger", default: OverlayTrigger.command)
    static let includeDisabledKey = SettingKey.feature("shortcuts", "includeDisabled", default: true)

    public static let showHotkey = HotkeyAction(
        id: "shortcuts.show", title: "Show keyboard shortcuts",
        defaultCombo: KeyCombo(keyCode: 44, modifiers: [.control, .option, .command]) // ⌃⌥⌘/
    )

    public let id: FeatureID = "shortcuts"
    public let displayName = "Shortcut Overlay"
    public let summary = "Press ⌘ twice and hold to see the current app's keyboard shortcuts."
    public let symbolName = "command.square"
    public let requiredPermissions: Set<Permission> = [.accessibility]

    private(set) var tapError: String?
    @ObservationIgnored private var controller: OverlayController?
    @ObservationIgnored private var tap: ModifierTap?
    @ObservationIgnored private var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        let controller = OverlayController(includeDisabled: { settings.value(Self.includeDisabledKey) })
        self.controller = controller
        try applyTrigger()
        context.lifetime.add { [weak self] in
            self?.tap?.stop()
            self?.tap = nil
            controller.close()
        }
        context.registerHotkey(Self.showHotkey) { controller.togglePinned() }
        context.registerCommand(Command(
            id: "shortcuts.show", title: "Show Keyboard Shortcuts", subtitle: "For the frontmost app",
            keywords: ["cheatsheet", "keys", "menu", "hotkeys"], symbolName: symbolName
        ) {
            // Let the palette close first so it doesn't take the key focus back.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                controller.togglePinned()
            }
        })
    }

    public func disable() {
        controller = nil
        settings = nil
        tapError = nil
    }

    /// Runs the modifier listener only while a double-press trigger is chosen.
    func applyTrigger() throws {
        guard let settings, let controller else { return }
        let trigger = settings.value(Self.triggerKey)
        if trigger == .off {
            tap?.stop()
            tap = nil
            return
        }
        guard tap == nil else { return }
        let tap = ModifierTap(trigger: { settings.value(Self.triggerKey) }) { [weak controller] event in
            controller?.handle(event)
        }
        do {
            try tap.start()
            self.tap = tap
            tapError = nil
        } catch {
            tapError = "\(error)"
            throw error
        }
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(ShortcutOverlaySettingsView(feature: self, settings: settings))
    }
}

struct ShortcutOverlaySettingsView: View {
    let feature: ShortcutOverlayFeature
    let settings: SettingsStore

    var body: some View {
        Picker("Show with", selection: Binding(
            get: { settings.value(ShortcutOverlayFeature.triggerKey) },
            set: { settings.set($0, for: ShortcutOverlayFeature.triggerKey); try? feature.applyTrigger() }
        )) {
            ForEach(OverlayTrigger.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        Text("Tap the key, then press it again and keep holding: the overlay stays while you hold it. Click an item to run it. The shortcut in Settings → Shortcuts (default ⌃⌥⌘/) and the palette command open it until you press Esc, with a filter field.")
            .font(.caption).foregroundStyle(.secondary)
        Toggle("Include items that are disabled right now (dimmed)", isOn: settings.binding(ShortcutOverlayFeature.includeDisabledKey))
        Text("Shortcuts come from the app's menu bar. Shortcuts that exist only inside a window (not in a menu) can't be listed.")
            .font(.caption).foregroundStyle(.secondary)
        if let error = feature.tapError {
            Text(error).font(.caption).foregroundStyle(.orange)
        }
    }
}
