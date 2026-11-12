import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Alt-Tab style switching between individual windows, with thumbnails.
@MainActor
@Observable
public final class SwitcherFeature: Feature {
    static let triggerKey = SettingKey.feature("switcher", "trigger", default: SwitcherTrigger.option)
    static let minimizedKey = SettingKey.feature("switcher", "includeMinimized", default: true)
    static let hiddenKey = SettingKey.feature("switcher", "includeHidden", default: true)
    static let otherSpacesKey = SettingKey.feature("switcher", "includeOtherSpaces", default: true)
    static let thumbnailsKey = SettingKey.feature("switcher", "thumbnails", default: true)

    public let id: FeatureID = "switcher"
    public let displayName = "Window Switcher"
    public let summary = "Hold ⌥ and press Tab to switch between individual windows, with live previews."
    public let symbolName = "rectangle.stack"
    public let requiredPermissions: Set<Permission> = [.accessibility]
    /// Without it: app icons instead of thumbnails, and no other-Space windows.
    public let optionalPermissions: Set<Permission> = [.screenRecording]

    private(set) var tapFailed = false
    @ObservationIgnored private var controller: SwitcherController?
    @ObservationIgnored private var settings: SettingsStore?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        tapFailed = false
        let tracker = FocusTracker()
        tracker.start()
        let controller = SwitcherController(tracker: tracker, options: {
            WindowListOptions(
                includeMinimized: settings.value(Self.minimizedKey),
                includeHidden: settings.value(Self.hiddenKey),
                includeOtherSpaces: settings.value(Self.otherSpacesKey)
            )
        }, wantsThumbnails: { settings.value(Self.thumbnailsKey) })
        self.controller = controller

        var isTriggerHeld: () -> Bool = { true }
        let keyTap = SwitcherKeyTap(
            trigger: { settings.value(Self.triggerKey) },
            isOpen: { controller.isOpen },
            onEvent: { event in
                switch event {
                case let .begin(backward):
                    controller.begin(backward: backward)
                    // Released before we got here (a quick tap): switch now
                    // instead of waiting for a release we already missed.
                    if controller.isOpen && !isTriggerHeld() { controller.handle(.release) }
                case let .input(input): controller.handle(input)
                }
            },
            onFailure: { [weak self] in
                controller.handle(.escape)
                self?.tapFailed = true
                HUD.show("Window switcher paused: macOS stopped its keyboard listener", symbol: "exclamationmark.triangle")
            }
        )
        isTriggerHeld = { [weak keyTap] in keyTap?.isTriggerHeld() ?? false }
        do {
            try keyTap.start()
        } catch {
            tracker.stop()
            throw error
        }
        context.lifetime.add {
            keyTap.stop()
            tracker.stop()
            controller.close()
        }
        context.registerSearchProvider(WindowSearchProvider(controller: controller))
        context.registerCommand(Command(
            id: "switcher.search", title: "Switch to Window…", keywords: ["window", "switch", "focus"], symbolName: symbolName
        ) { context.openPalette(query: "win ") })
    }

    public func disable() {
        controller = nil
        settings = nil
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(SwitcherSettingsView(feature: self, settings: settings))
    }
}

/// Palette results for "win …".
@MainActor
final class WindowSearchProvider: SearchProvider {
    let keyword = "win"
    let title = "Window"
    private weak var controller: SwitcherController?

    init(controller: SwitcherController) {
        self.controller = controller
    }

    func results(for query: String, limit: Int) -> [SearchResult] {
        guard let controller else { return [] }
        let needle = query.lowercased()
        return controller.currentWindows()
            .filter { needle.isEmpty || $0.title.lowercased().contains(needle) || $0.appName.lowercased().contains(needle) }
            .prefix(limit)
            .map { record in
                let appURL = NSRunningApplication(processIdentifier: record.pid)?.bundleURL
                return SearchResult(
                    id: "\(record.id)", title: record.title,
                    subtitle: record.state == .normal ? record.appName : "\(record.appName) · \(record.state.label)",
                    icon: appURL.map { .file($0) } ?? .symbol("macwindow"),
                    primaryAction: { [weak controller] in controller?.focus(record) }
                )
            }
    }
}

extension WindowState {
    var label: String {
        switch self {
        case .normal: "Open"
        case .minimized: "Minimized"
        case .hidden: "Hidden"
        case .otherSpace: "Other Space"
        }
    }
}

struct SwitcherSettingsView: View {
    let feature: SwitcherFeature
    let settings: SettingsStore

    var body: some View {
        Picker("Shortcut", selection: settings.binding(SwitcherFeature.triggerKey)) {
            ForEach(SwitcherTrigger.allCases, id: \.self) { Text($0.label).tag($0) }
        }
        Text("Hold the modifier and press Tab to move forward (add ⇧ to go back), release to switch. While open: arrows move, ↩ switches, Esc cancels, Q quits the app, W closes the window.")
            .font(.caption).foregroundStyle(.secondary)
        Toggle("Show live previews (needs Screen Recording)", isOn: settings.binding(SwitcherFeature.thumbnailsKey))
        Toggle("Include minimized windows", isOn: settings.binding(SwitcherFeature.minimizedKey))
        Toggle("Include windows of hidden apps", isOn: settings.binding(SwitcherFeature.hiddenKey))
        Toggle("Include windows on other Spaces", isOn: settings.binding(SwitcherFeature.otherSpacesKey))
        Text("Windows on other Spaces need Screen Recording to be listed. Choosing one activates its app; macOS decides whether to switch Space.")
            .font(.caption).foregroundStyle(.secondary)
        if feature.tapFailed {
            Text("macOS stopped the switcher's keyboard listener, so it has been paused and your keyboard works normally. Turn the feature off and on to restart it.")
                .font(.caption).foregroundStyle(.orange)
        }
    }
}
