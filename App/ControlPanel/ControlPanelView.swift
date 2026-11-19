import OmniCore
import OmniPlatform
import SwiftUI

/// What the panel's controls do; implemented by `ControlPanelController`.
@MainActor
struct ControlPanelActions {
    var activate: (ControlPanelFocus.Target) -> Void
    var turnOn: (String) -> Void
    var menu: (QuickAccessID) -> [MenuEntry]
    var settingsShortcut: String
}

/// The menu bar panel (design: "Control panel (menu bar)"): header, a grid
/// of eight actions, what's running now, more actions, Settings and Quit.
struct ControlPanelView: View {
    @Bindable var model: ControlPanelModel
    let actions: ControlPanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            grid
            if let id = model.turnOnPrompt, let action = model.action(id), case let .off(feature) = action.state {
                turnOnRow(id: id, feature: feature)
            }
            if !model.running.isEmpty { running }
            if !model.more.isEmpty { more }
            footer
        }
        .frame(width: 364, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(red: 36 / 255, green: 37 / 255, blue: 44 / 255).opacity(0.92)))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.04)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .allSetWindowStyle()
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { actions.activate(.settings) } label: {
                HStack(spacing: 10) {
                    AllSetLogo(size: 30)
                    Text(L10n.AllSet.appName).font(AS.font(16, .semibold)).foregroundStyle(AS.text)
                }
            }
            .buttonStyle(.plain)
            .help(L10n.App.settings)
            Spacer()
            if let shortcut = ShortcutLookupText.controlPanel { KeyCaps(shortcut) }
        }
        .padding(.horizontal, 2)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(model.grid) { action in
                GridButton(action: action, focused: isFocused(.action(action.id))) { actions.activate(.action(action.id)) }
                    .contextMenu { MenuEntriesView(entries: menu(for: action)) }
            }
        }
    }

    private func menu(for action: ControlPanelModel.Action) -> [MenuEntry] {
        guard case let .quickAccess(id) = action.kind, case .ready = action.state else {
            if case .recording = action.state, case let .quickAccess(id) = action.kind { return actions.menu(id) }
            return []
        }
        return actions.menu(id)
    }

    private func turnOnRow(id: String, feature: String) -> some View {
        HStack {
            Text(L10n.PanelUI.featureIsOff(feature)).font(AS.font(12.5)).foregroundStyle(AS.text)
            Spacer()
            Button(L10n.PanelUI.turnOn) { actions.turnOn(id) }.buttonStyle(.asPrimary)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AS.tileBorder, lineWidth: 1))
    }

    // MARK: Running now

    private var running: some View {
        section(L10n.PanelUI.runningNow) {
            ForEach(model.running) { row in
                HStack(spacing: 10) {
                    FeatureIcon(row.featureID, size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.title).font(AS.font(13, .medium)).foregroundStyle(AS.text).lineLimit(1)
                        Text(row.detail).font(AS.font(11.5).monospacedDigit()).foregroundStyle(AS.textSecondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    switch row.control {
                    case let .toggle(isOn):
                        ASSwitch(row.title, isOn: Binding(get: { isOn }, set: { _ in actions.activate(.running(row.id)) }))
                            .overlay(focusRing(.running(row.id)))
                    case let .button(title):
                        Button(title) { actions.activate(.running(row.id)) }
                            .buttonStyle(SmallButtonStyle())
                            .overlay(focusRing(.running(row.id)))
                    case .none:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 46)
            }
        }
    }

    // MARK: More

    private var more: some View {
        section(L10n.PanelUI.more) {
            ForEach(model.more) { action in
                Button { actions.activate(.action(action.id)) } label: {
                    HStack(spacing: 10) {
                        FeatureIcon(action.featureID, size: 22)
                        Text(action.title).font(AS.body).foregroundStyle(AS.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if case .off = action.state {
                            Text(L10n.PanelUI.off).font(AS.font(11.5)).foregroundStyle(AS.textTertiary)
                        } else if let shortcut = action.shortcut {
                            KeyCaps(shortcut, spacing: 1.5)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowButtonStyle(focused: isFocused(.action(action.id))))
                .opacity(isOff(action) ? 0.55 : 1)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(AS.font(11.5, .semibold)).foregroundStyle(AS.textSecondary)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ASDividedStack { content() }
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AS.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AS.tileBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button { actions.activate(.settings) } label: {
                HStack(spacing: 6) { Text(L10n.PanelUI.settings).font(AS.body).foregroundStyle(AS.text); KeyCaps(actions.settingsShortcut) }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(RowButtonStyle(focused: isFocused(.settings), radius: 7))
            Spacer()
            Button { actions.activate(.quit) } label: {
                HStack(spacing: 6) { Text(L10n.PanelUI.quit).font(AS.body).foregroundStyle(AS.text); KeyCaps("⌘Q") } // l10n-ignore
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(RowButtonStyle(focused: isFocused(.quit), radius: 7))
        }
        .padding(.horizontal, -4)
        .padding(.bottom, -4)
    }

    private func isOff(_ action: ControlPanelModel.Action) -> Bool {
        if case .off = action.state { true } else { false }
    }

    private func isFocused(_ target: ControlPanelFocus.Target) -> Bool {
        model.showsFocusRing && model.focus.current == target
    }

    @ViewBuilder private func focusRing(_ target: ControlPanelFocus.Target) -> some View {
        if isFocused(target) {
            RoundedRectangle(cornerRadius: AS.controlRadius).strokeBorder(AS.blue, lineWidth: 2).padding(-3)
        }
    }
}

/// The control panel's own shortcut, set by the controller when it opens.
@MainActor
enum ShortcutLookupText {
    static var controlPanel: String?
}

/// One of the eight grid buttons: glyph tile, name, shortcut (or live state).
private struct GridButton: View {
    let action: ControlPanelModel.Action
    let focused: Bool
    let perform: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: perform) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    icon
                    if case .needsPermission = action.state {
                        LineIcon(ASIcon.warning, size: 10, lineWidth: 2.2, color: AS.orange)
                            .background(Circle().fill(AS.panel).padding(-2))
                            .offset(x: 5, y: -4)
                    }
                }
                Text(title).font(AS.font(11.5, .medium)).foregroundStyle(AS.text).lineLimit(1).minimumScaleFactor(0.8)
                subtitle.frame(height: 16)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(background))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(focused ? AS.blue : AS.tileBorder, lineWidth: focused ? 2 : 1)
        }
        .opacity(isOff ? 0.55 : 1)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(help)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var icon: some View {
        if case .recording = action.state {
            GlassTile(size: 34, glow: AS.red) {
                Image(systemName: "stop.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(AS.red)
            }
        } else {
            FeatureIcon(action.featureID, size: 34)
        }
    }

    private var title: String {
        if case let .recording(elapsed) = action.state { return elapsed }
        return action.title
    }

    @ViewBuilder private var subtitle: some View {
        if case .off = action.state {
            Text(L10n.PanelUI.off).font(AS.font(10.5)).foregroundStyle(AS.textTertiary)
        } else if let shortcut = action.shortcut {
            KeyCaps(shortcut, spacing: 1.5, size: 16)
        } else {
            Color.clear
        }
    }

    private var isOff: Bool { if case .off = action.state { true } else { false } }

    private var help: String {
        switch action.state {
        case let .off(feature): L10n.PanelUI.featureIsOff(feature)
        case .needsPermission: [action.title, L10n.Status.needsPermission].joined(separator: " — ") // l10n-ignore
        case let .recording(elapsed): L10n.PanelUI.stop(elapsed)
        case .ready: action.title
        }
    }

    private var background: Color {
        switch action.state {
        case .ready(true): AS.green.opacity(0.16)
        case .recording: AS.red.opacity(0.20)
        default: hovering ? Color.white.opacity(0.09) : AS.cardFill
        }
    }
}

/// A full-width row button with a hover fill and keyboard focus ring.
private struct RowButtonStyle: ButtonStyle {
    let focused: Bool
    var radius: CGFloat = 0
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(configuration.isPressed ? Color.white.opacity(0.12) : (hovering || focused ? Color.white.opacity(0.07) : .clear)))
            .overlay {
                if focused { RoundedRectangle(cornerRadius: max(radius, 6), style: .continuous).strokeBorder(AS.blue, lineWidth: 2) }
            }
            .onHover { hovering = $0 }
    }
}

/// The small "Snooze" button.
private struct SmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AS.font(12))
            .foregroundStyle(AS.text)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0.12)))
    }
}

/// Six small window-layout buttons, each drawn as a screen with the window's place.
struct LayoutGrid: View {
    let layouts: [ControlPanelModel.Layout]
    let focused: ControlPanelFocus.Target?
    let action: (String) -> Void

    var body: some View {
        // Buttons share the row's width, so the grid never pushes the panel wider.
        HStack(spacing: OmniStyle.s1) {
            ForEach(layouts) { layout in
                Button { action(layout.id) } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).strokeBorder(AS.textSecondary, lineWidth: 1)
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xBD71E4))
                                    .frame(width: max(2, geometry.size.width * layout.span.width - 2))
                                    .offset(x: geometry.size.width * layout.span.x + 1)
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(width: 40, height: 24)
                        Text(layout.title).font(AS.font(10.5)).foregroundStyle(AS.text).lineLimit(1).minimumScaleFactor(0.7)
                        if let shortcut = layout.shortcut { KeyCaps(shortcut, spacing: 1, size: 14) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if focused == .layout(layout.id) {
                        RoundedRectangle(cornerRadius: AS.controlRadius).strokeBorder(AS.blue, lineWidth: 2)
                    }
                }
                .help(layout.title)
            }
        }
    }
}

/// SwiftUI rendering of a feature's options menu (for right-click on tiles).
struct MenuEntriesView: View {
    let entries: [MenuEntry]

    var body: some View {
        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
            switch entry {
            case .separator: Divider()
            case let .header(text): Text(text)
            case let .submenu(title, children): Menu(title) { MenuEntriesView(entries: children) }
            case let .action(action):
                Button {
                    if let question = action.confirmation, !MenuBuilder.confirm(question) { return }
                    action.perform()
                } label: {
                    if action.isChecked { Label(action.title, systemImage: "checkmark") } else { Text(action.title) }
                }
                .disabled(!action.isEnabled)
            }
        }
    }
}
