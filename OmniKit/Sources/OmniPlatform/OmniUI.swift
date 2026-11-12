import AppKit
import OmniCore
import SwiftUI

/// The shared visual language for every Omni window, panel and popover.
public enum OmniStyle {
    public static let panelRadius: CGFloat = 12
    public static let cardRadius: CGFloat = 10
    public static let controlRadius: CGFloat = 6
    /// The spacing scale; nothing else is used.
    public static let s1: CGFloat = 4, s2: CGFloat = 8, s3: CGFloat = 12, s4: CGFloat = 16, s5: CGFloat = 24

    /// System "Reduce motion": no fades or slides.
    public static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    /// System "Increase contrast": visible borders.
    public static var increaseContrast: Bool { NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast }

    /// `animation` unless Reduce Motion is on.
    public static func motion(_ animation: Animation = .easeOut(duration: 0.18)) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// A keyboard shortcut in a small capsule, the same everywhere.
public struct ShortcutChip: View {
    let text: String
    public init(_ text: String) { self.text = text }
    public init(_ combo: KeyCombo) { text = combo.displayString }

    public var body: some View {
        Text(text)
            .font(.caption.monospacedDigit().weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(.quaternary))
            .accessibilityLabel(L10n.A11y.shortcut(KeySpeech.spoken(text)))
    }
}

/// Feature state as an icon and a word (color is never the only signal).
public struct StatusBadge: View {
    public enum Kind: Equatable {
        case working, needsPermission, off, problem(String)
    }

    let kind: Kind
    public init(_ kind: Kind) { self.kind = kind }

    public var body: some View {
        Label {
            Text(text).lineLimit(1)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .font(.caption)
        .foregroundStyle(kind == .off ? .secondary : .primary)
    }

    private var text: String {
        switch kind {
        case .working: L10n.Status.working
        case .needsPermission: L10n.Status.needsPermission
        case .off: L10n.Status.off
        case let .problem(detail): L10n.Status.problem(detail)
        }
    }

    private var symbol: String {
        switch kind {
        case .working: "checkmark.circle.fill"
        case .needsPermission: "exclamationmark.triangle.fill"
        case .off: "circle"
        case .problem: "xmark.octagon.fill"
        }
    }

    public var color: Color {
        switch kind {
        case .working: .green
        case .needsPermission: .orange
        case .off: .secondary
        case .problem: .red
        }
    }
}

/// "Nothing here yet" with what to do about it.
public struct EmptyState: View {
    let symbol: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(symbol: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: OmniStyle.s2) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.tertiary)
            Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action).controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(OmniStyle.s3)
    }
}

/// Small uppercase section title (control panel, onboarding).
public struct SectionHeader: View {
    let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        Text(title.uppercased(with: .current))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

public extension View {
    /// Panel/card background: material, rounded, with a border under Increase Contrast.
    func omniPanelBackground(radius: CGFloat = OmniStyle.panelRadius, material: Material = .regularMaterial) -> some View {
        modifier(PanelBackground(radius: radius, material: material))
    }

    /// Marks a setting so Settings search can scroll to it and highlight it.
    func settingsAnchor(_ id: String) -> some View {
        modifier(SettingsAnchorModifier(anchor: id))
    }
}

private struct PanelBackground: ViewModifier {
    let radius: CGFloat
    let material: Material

    func body(content: Content) -> some View {
        content
            .background(material, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(OmniStyle.increaseContrast ? 1 : 0.35), lineWidth: 1)
            }
    }
}

/// The setting Settings search wants to highlight right now.
public struct SettingsHighlightKey: EnvironmentKey {
    public static let defaultValue: String? = nil
}

public extension EnvironmentValues {
    var settingsHighlight: String? {
        get { self[SettingsHighlightKey.self] }
        set { self[SettingsHighlightKey.self] = newValue }
    }
}

private struct SettingsAnchorModifier: ViewModifier {
    let anchor: String
    @Environment(\.settingsHighlight) private var highlight

    func body(content: Content) -> some View {
        content
            .id(anchor)
            .background {
                RoundedRectangle(cornerRadius: OmniStyle.controlRadius)
                    .fill(Color.accentColor.opacity(highlight == anchor ? 0.18 : 0))
                    .padding(-4)
                    .animation(OmniStyle.motion(.easeInOut(duration: 0.3)), value: highlight)
            }
    }
}

/// Spoken names of shortcut symbols for VoiceOver.
public enum KeySpeech {
    public static func spoken(_ text: String) -> String {
        let names: [Character: String] = ["⌃": "Control ", "⌥": "Option ", "⇧": "Shift ", "⌘": "Command ", "↩": "Return", "⌫": "Delete", "←": "Left Arrow", "→": "Right Arrow", "↑": "Up Arrow", "↓": "Down Arrow", "⎋": "Escape", "⇥": "Tab"] // l10n-ignore
        return text.map { names[$0] ?? String($0) }.joined()
    }
}
