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
        id: "shortcuts.show", title: L10n.Cheatsheet.showTitle,
        defaultCombo: KeyCombo(keyCode: 44, modifiers: [.control, .option, .command]) // ⌃⌥⌘/
    )

    public let id: FeatureID = "shortcuts"
    public var displayName: String { L10n.Cheatsheet.name }
    public var summary: String { L10n.Cheatsheet.summary }
    public let symbolName = "command.square"
    public let requiredPermissions: Set<Permission> = [.accessibility]

    private(set) var tapError: String?
    @ObservationIgnored private var controller: OverlayController?
    @ObservationIgnored private var tap: ModifierTap?
    @ObservationIgnored private(set) var settings: SettingsStore?

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
            id: "shortcuts.show", title: L10n.Cheatsheet.showTitle, subtitle: L10n.Cheatsheet.showSubtitle,
            keywords: ["cheatsheet", "keys", "menu", "hotkeys"], symbolName: symbolName
        ) {
            // Let the menu close first so it doesn't take the key focus back.
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
            tapError = L10n.Cheatsheet.cannotWatchKeys
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
        VStack(alignment: .leading, spacing: 14) {
            ASSection(footer: L10n.Cheatsheet.sourceHelp) {
                ASRow(L10n.Cheatsheet.openWith, subtitle: L10n.Cheatsheet.openWithHelp) {
                    ASPopUp(L10n.Cheatsheet.openWith, selection: Binding(
                        get: { settings.value(ShortcutOverlayFeature.triggerKey) },
                        set: { settings.set($0, for: ShortcutOverlayFeature.triggerKey); try? feature.applyTrigger() }
                    ), options: OverlayTrigger.allCases.map { ($0, $0.label) })
                }
                .settingsAnchor(ShortcutOverlayAnchor.trigger)
                ASToggleRow(L10n.Cheatsheet.includeDisabled, subtitle: L10n.Cheatsheet.includeDisabledNote,
                            isOn: settings.binding(ShortcutOverlayFeature.includeDisabledKey))
                    .settingsAnchor(ShortcutOverlayAnchor.includeDisabled)
            }
            if let error = feature.tapError {
                ASCard(padding: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        LineIcon(ASIcon.warning, size: 14, lineWidth: 2, color: AS.orange).padding(.top, 1)
                        Text(error).font(AS.body).foregroundStyle(AS.text).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// The example under the header: a sheet of an app's menu shortcuts.
struct ShortcutOverlayHero: View {
    private let pink = Color(hex: 0xFF5374)
    private let rows: [(width: CGFloat, keys: [String])] = [
        (110, ["⌘", "C"]), (84, ["⌘", "V"]), (128, ["⇧", "⌘", "Z"]), (96, ["⌘", "F"]), // l10n-ignore
    ]

    var body: some View {
        ASStage(tint: pink) {
            VStack(spacing: 9) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    let first = index == 0
                    HStack(spacing: 24) {
                        Capsule().fill(first ? .white : .white.opacity(0.32)).frame(width: row.width, height: 8)
                        Spacer(minLength: 0)
                        HStack(spacing: 3) {
                            ForEach(Array(row.keys.enumerated()), id: \.offset) { _, key in
                                Text(key)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(first ? Color(hex: 0x3A0612) : .white)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 22, minHeight: 22)
                                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(first ? pink : .white.opacity(0.12)))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(width: 300)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: 0x15161B)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Cheatsheet.heroLabel)
        .accessibilityAddTraits(.isImage)
    }
}
