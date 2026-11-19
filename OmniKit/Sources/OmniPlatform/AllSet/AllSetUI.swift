import AppKit
import OmniCore
import SwiftUI

// The All Set look: a dark window, glass icon tiles, grouped rows on soft
// cards, green switches and key caps. Values are taken from the design file
// ("Tolio Settings redesign" canvas); keep them in sync with it.

/// Design tokens.
public enum AS {
    // Surfaces
    public static let window = Color(hex: 0x1C1C1E)
    public static let sidebar = Color(hex: 0x252528)
    public static let stage = Color(hex: 0x17181F)
    public static let panel = Color(hex: 0x24252C)
    public static let cardFill = Color.white.opacity(0.05)
    public static let cardBorder = Color.white.opacity(0.06)
    public static let tileBorder = Color.white.opacity(0.07)
    public static let divider = Color.white.opacity(0.07)
    public static let controlFill = Color.white.opacity(0.10)
    public static let selectedFill = Color.white.opacity(0.10)
    public static let fieldFill = Color.white.opacity(0.08)

    // Text
    public static let text = Color(hex: 0xF5F5F7)
    public static let textSecondary = Color(hex: 0xA1A1A6)
    public static let textTertiary = Color(hex: 0x98989D)
    public static let textBody = Color(hex: 0xC7C7CC)
    public static let icon = Color(hex: 0xD1D1D6)

    // Accents
    public static let accent = Color(hex: 0x3156E8)
    public static let link = Color(hex: 0x9DB2FF)
    public static let blue = Color(hex: 0x0A84FF)
    public static let green = Color(hex: 0x30D158)
    public static let orange = Color(hex: 0xFF9F0A)
    public static let red = Color(hex: 0xFF453A)
    public static let destructiveFill = Color(red: 1, green: 69 / 255, blue: 58 / 255).opacity(0.18)
    public static let destructiveText = Color(hex: 0xFF8A80)
    public static let switchOff = Color.white.opacity(0.16)

    // Type
    public static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    public static let pageTitle = font(15, .semibold)
    public static let heroTitle = font(18, .bold)
    public static let body = font(13)
    public static let sectionTitle = font(12, .semibold)
    public static let footnote = font(11.5)

    // Shape
    public static let cardRadius: CGFloat = 10
    public static let tileRadius: CGFloat = 14
    public static let controlRadius: CGFloat = 6
}

public extension Color {
    /// A color from 0xRRGGBB.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

// MARK: - Feature looks

/// A feature's glyph and colors.
public struct FeatureLook: Sendable {
    public let glyph: FeatureGlyph.Glyph
    /// The glow in the tile's lower right corner.
    public let glow: Color
    /// Glyph color on dark tiles.
    public let ink: Color
    /// Glyph color on light tiles.
    public let lightInk: Color
    public let lightGlow: Color

    public static func of(_ id: FeatureID) -> FeatureLook? {
        table[id.rawValue]
    }

    /// Feature IDs in the order the design lists them (sidebar, onboarding).
    public static let designOrder: [FeatureID] = [
        "clipboard", "island", "dropring", "deskminder", "keepawake", "windows", "screenshots",
        "keyboardclean", "switcher", "capturetext", "stickynotes", "shortcuts", "textactions", "systemstats",
    ]

    private static let table: [String: FeatureLook] = [
        "clipboard": .init(.clipboardHistory, 0x007AFF, 0x2E92FF, 0x0073F0),
        "island": .init(.notchIsland, 0xE5E5EA, 0xE5E5EA, 0x1A1A1C, lightGlow: 0x1C1C1E),
        "dropring": .init(.dropRing, 0x32ADE6, 0x57BCEA, 0x2FA3D8),
        "deskminder": .init(.deskMinder, 0xFF9500, 0xFFA82E, 0xF08C00),
        "keepawake": .init(.energyMode, 0xA2845E, 0xB39A7B, 0x987C58),
        "windows": .init(.windowLayouts, 0xAF52DE, 0xBD71E4, 0xA44DD1),
        "screenshots": .init(.screenshots, 0xFF3B30, 0xFF5E55, 0xF0372D),
        "keyboardclean": .init(.lockKeyboard, 0xAEAEB2, 0xAEAEB2, 0x85858A, lightGlow: 0x8E8E93),
        "switcher": .init(.windowSwitcher, 0x5856D6, 0x7674DD, 0x5351C9),
        "capturetext": .init(.captureText, 0x00B8B0, 0x2EC5BE, 0x00ADA5),
        "stickynotes": .init(.desktopNotes, 0xFFD60A, 0xFFD60A, 0xE6AD00, lightGlow: 0xF5B800),
        "shortcuts": .init(.shortcutCheatSheet, 0xFF2D55, 0xFF5374, 0xF02A50),
        "textactions": .init(.textActions, 0x30A0BE, 0x55B1CA, 0x2D96B3),
        "systemstats": .init(.systemStats, 0x34C759, 0x59D177, 0x31BB54),
    ]

    init(_ glyph: FeatureGlyph.Glyph, _ glow: UInt32, _ ink: UInt32, _ lightInk: UInt32, lightGlow: UInt32? = nil) {
        self.glyph = glyph
        self.glow = Color(hex: glow)
        self.ink = Color(hex: ink)
        self.lightInk = Color(hex: lightInk)
        self.lightGlow = Color(hex: lightGlow ?? glow)
    }
}

// MARK: - Glass tiles

/// The rounded glass square every icon sits in.
public struct GlassTile<Content: View>: View {
    let size: CGFloat
    let radius: CGFloat
    let glow: Color?
    let content: Content
    @Environment(\.colorScheme) private var scheme

    public init(size: CGFloat, radius: CGFloat? = nil, glow: Color? = nil, @ViewBuilder content: () -> Content) {
        self.size = size
        self.radius = radius ?? (size * 0.27).rounded(.toNearestOrEven)
        self.glow = glow
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let light = scheme == .light
        ZStack {
            shape.fill(LinearGradient(colors: light ? [Color(hex: 0xF4F5F9), Color(hex: 0xE6E8EF)] : [Color(hex: 0x3A3C46), Color(hex: 0x24252C)],
                                      startPoint: .top, endPoint: .bottom))
            if let glow {
                shape.fill(EllipticalGradient(colors: [glow.opacity(light ? 0.24 : 0.32), glow.opacity(0)],
                                              center: UnitPoint(x: 0.88, y: 1), startRadiusFraction: 0, endRadiusFraction: 0.62))
            }
            shape.fill(EllipticalGradient(colors: [.white.opacity(light ? 0.95 : 0.20), .white.opacity(0)],
                                          center: UnitPoint(x: 0.18, y: 0), startRadiusFraction: 0, endRadiusFraction: 0.58))
            content
        }
        .frame(width: size, height: size)
        .overlay {
            shape.strokeBorder(.white.opacity(light ? 0.85 : 0.13), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            // The bright top edge.
            shape.stroke(.white.opacity(light ? 0.95 : 0.20), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.08)))
        }
        .accessibilityHidden(true)
    }
}

/// A feature's icon: its glyph in a tinted glass tile.
public struct FeatureIcon: View {
    let id: FeatureID
    let size: CGFloat
    let fallbackSymbol: String
    @Environment(\.colorScheme) private var scheme

    public init(_ id: FeatureID, size: CGFloat, fallbackSymbol: String = "square.grid.2x2") {
        self.id = id
        self.size = size
        self.fallbackSymbol = fallbackSymbol
    }

    public var body: some View {
        let look = FeatureLook.of(id)
        let light = scheme == .light
        GlassTile(size: size, glow: light ? look?.lightGlow : look?.glow) {
            if let look {
                FeatureGlyph(look.glyph, color: light ? look.lightInk : look.ink)
                    .frame(width: (size * 0.73).rounded(), height: (size * 0.73).rounded())
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(AS.icon)
            }
        }
    }
}

/// A line icon in a plain glass tile (sidebar pages, permission rows).
public struct LineIconTile: View {
    let data: String
    let size: CGFloat
    let iconSize: CGFloat?

    public init(_ data: String, size: CGFloat, iconSize: CGFloat? = nil) {
        self.data = data
        self.size = size
        self.iconSize = iconSize
    }

    public var body: some View {
        GlassTile(size: size) {
            LineIcon(data, size: iconSize ?? (size * 0.6).rounded(), color: AS.icon)
        }
    }
}

/// Design icon paths (16×16 grid) used in more than one place.
public enum ASIcon {
    public static let overview = "M3 3h4v4H3zM9 3h4v4H9zM3 9h4v4H3zM9 9h4v4H9z"
    public static let menuBar = "M2 4h12v8H2zM2 6.5h12"
    public static let profile = "M8 2.8a2.6 2.6 0 1 0 .01 0M3 13.5c.6-2.6 2.6-4 5-4s4.4 1.4 5 4"
    public static let general = "M3 5h6M12 5h1M3 11h1M7 11h6M10.5 3.5v3M5.5 9.5v3"
    public static let permissions = "M8 2l5 2v4c0 3-2.2 5-5 6-2.8-1-5-3-5-6V4z"
    public static let shortcuts = "M6 6h4v4H6zM6 6V4.5A1.5 1.5 0 1 0 4.5 6H6M10 6V4.5A1.5 1.5 0 1 1 11.5 6H10M6 10v1.5A1.5 1.5 0 1 1 4.5 10H6M10 10v1.5a1.5 1.5 0 1 0 1.5-1.5H10"
    public static let checkCircle = "M8 2a6 6 0 1 0 .01 0M5.5 8.2l1.8 1.8 3.4-3.6"
    public static let warning = "M8 2.5l6 10.5H2zM8 7v2.5M8 11.5h.01"
    public static let lock = "M3.5 7.5h9v6h-9zM5.5 7.5V5a2.5 2.5 0 0 1 5 0v2.5"
    public static let search = "M7 2.5a4.5 4.5 0 1 0 .01 0M10.5 10.5L14 14"
    public static let chevronRight = "M6 3.5l4.5 4.5L6 12.5"
    public static let chevronLeft = "M10 3.5L5.5 8l4.5 4.5"
    public static let plus = "M8 3v10M3 8h10"
    public static let accessibility = "M8 2a6 6 0 1 0 .01 0M8 4.6h.01M4.8 6.6h6.4M8 6.6v2.6M8 9.2l-1.8 3M8 9.2l1.8 3"
    public static let screen = "M2.5 3.5h11v7h-11zM6 13h4M8 10.5V13"
    public static let microphone = "M8 2.5a1.8 1.8 0 0 1 1.8 1.8v3.4a1.8 1.8 0 0 1-3.6 0V4.3A1.8 1.8 0 0 1 8 2.5zM4.5 7.5a3.5 3.5 0 0 0 7 0M8 11v2.5"
    public static let key = "M10.5 3a3 3 0 1 0 .01 0M8.4 7.6L3 13M5 11l1.6 1.6"
    public static let pin = "M6 2.5h4l-.6 4 2.1 2.2H4.5l2.1-2.2zM8 8.7v4.8"
    public static let picture = "M2 12l3.5-4 2.5 2.5 2-2L14 12M11 4.8h.01"
    /// Up/down chevrons of a pop-up button (10×14 grid).
    public static let popUpChevrons = "M2 5l3-3 3 3M2 9l3 3 3-3"
}

// MARK: - Controls

/// The design's switch: 36×22, green when on.
public struct ASSwitchStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(OmniStyle.motion(.easeOut(duration: 0.15))) { configuration.isOn.toggle() }
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule().fill(configuration.isOn ? AS.green : AS.switchOff)
                Circle().fill(.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    .padding(2)
            }
            .frame(width: 36, height: 22)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

public extension ToggleStyle where Self == ASSwitchStyle {
    static var asSwitch: ASSwitchStyle { ASSwitchStyle() }
}

/// A labelled switch with the label hidden (rows show their own text).
public struct ASSwitch: View {
    let label: String
    @Binding var isOn: Bool

    public init(_ label: String, isOn: Binding<Bool>) {
        self.label = label
        _isOn = isOn
    }

    public var body: some View {
        Toggle(label, isOn: $isOn).toggleStyle(.asSwitch).labelsHidden()
    }
}

/// Button looks.
public struct ASButtonStyle: ButtonStyle {
    public enum Kind { case secondary, primary, destructive, plain }
    let kind: Kind
    let height: CGFloat
    let fontSize: CGFloat
    @Environment(\.isEnabled) private var enabled

    public init(_ kind: Kind = .secondary, height: CGFloat = 26, fontSize: CGFloat = 13) {
        self.kind = kind
        self.height = height
        self.fontSize = fontSize
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: kind == .primary ? .semibold : .regular))
            .foregroundStyle(foreground)
            .padding(.horizontal, height >= 34 ? 20 : 12)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: height >= 34 ? 9 : AS.controlRadius, style: .continuous).fill(background))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .secondary: .white
        case .primary: .white
        case .destructive: AS.destructiveText
        case .plain: AS.text
        }
    }

    private var background: Color {
        switch kind {
        case .secondary: AS.controlFill
        case .primary: AS.accent
        case .destructive: AS.destructiveFill
        case .plain: .clear
        }
    }
}

public extension ButtonStyle where Self == ASButtonStyle {
    static var asSecondary: ASButtonStyle { ASButtonStyle(.secondary) }
    static var asPrimary: ASButtonStyle { ASButtonStyle(.primary) }
    static var asDestructive: ASButtonStyle { ASButtonStyle(.destructive) }
    /// The large buttons at the bottom of onboarding (34 pt).
    static var asLargePrimary: ASButtonStyle { ASButtonStyle(.primary, height: 34, fontSize: 14) }
    static var asLargeSecondary: ASButtonStyle { ASButtonStyle(.secondary, height: 34, fontSize: 14) }
}

/// A pop-up menu that looks like the design's: value and ⌃⌄ chevrons on a soft fill.
public struct ASPopUp<Value: Hashable>: View {
    let label: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    public init(_ label: String, selection: Binding<Value>, options: [(value: Value, title: String)]) {
        self.label = label
        _selection = selection
        self.options = options
    }

    public var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    if option.value == selection { Label(option.title, systemImage: "checkmark") } else { Text(option.title) }
                }
            }
        } label: {
            ASPopUpLabel(options.first { $0.value == selection }?.title ?? "")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(label)
        .accessibilityValue(options.first { $0.value == selection }?.title ?? "")
    }
}

/// The face of a pop-up button; also usable as a `Menu` label.
public struct ASPopUpLabel: View {
    let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        HStack(spacing: 6) {
            Text(title).lineLimit(1)
            LineIcon(ASIcon.popUpChevrons, size: 10, lineWidth: 1.6, viewBox: 10)
                .frame(width: 10, height: 12)
        }
        .font(AS.body)
        .foregroundStyle(AS.text)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).fill(AS.controlFill))
        .contentShape(Rectangle())
    }
}

/// A segmented choice on a soft track.
public struct ASSegmented<Value: Hashable>: View {
    public enum Size { case small, regular, wide }
    let label: String
    @Binding var selection: Value
    let options: [(value: Value, title: String)]
    let size: Size

    public init(_ label: String, selection: Binding<Value>, options: [(value: Value, title: String)], size: Size = .regular) {
        self.label = label
        _selection = selection
        self.options = options
        self.size = size
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title)
                        .font(.system(size: size == .small ? 12 : 13))
                        .foregroundStyle(size == .wide && !selected ? AS.textBody : AS.text)
                        .padding(.horizontal, size == .small ? 10 : 14)
                        .frame(maxWidth: size == .wide ? .infinity : nil)
                        .frame(height: size == .small ? 20 : (size == .wide ? 26 : 22))
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(selected ? Color.white.opacity(0.20) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(AS.fieldFill))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// The design's slider: thin blue track and a white knob, with an optional caption.
public struct ASSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double?
    let width: CGFloat

    public init(_ label: String, value: Binding<Double>, in range: ClosedRange<Double> = 0 ... 1, step: Double? = nil, width: CGFloat = 200) {
        self.label = label
        _value = value
        self.range = range
        self.step = step
        self.width = width
    }

    public var body: some View {
        let fraction = CGFloat((value - range.lowerBound) / max(range.upperBound - range.lowerBound, .ulpOfOne))
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.14)).frame(height: 4)
            Capsule().fill(AS.blue).frame(width: max(4, width * fraction), height: 4)
            Circle().fill(.white).frame(width: 18, height: 18)
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
                .offset(x: width * fraction - 9)
        }
        .frame(width: width, height: 20)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            set(Double(min(max(drag.location.x / width, 0), 1)))
        })
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(((value - range.lowerBound) / (range.upperBound - range.lowerBound) * 100).rounded())) %") // l10n-ignore
        .accessibilityAdjustableAction { direction in
            let delta = step ?? (range.upperBound - range.lowerBound) / 10
            value = min(max(value + (direction == .increment ? delta : -delta), range.lowerBound), range.upperBound)
        }
    }

    private func set(_ fraction: Double) {
        var v = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        if let step { v = (v / step).rounded() * step }
        value = min(max(v, range.lowerBound), range.upperBound)
    }
}

// MARK: - Keys

/// One key cap, like the design's `<kbd>`.
public struct KeyCap: View {
    let key: String
    let size: CGFloat

    public init(_ key: String, size: CGFloat = 18) {
        self.key = key
        self.size = size
    }

    public var body: some View {
        Text(key)
            .font(.system(size: size * 11 / 18))
            .foregroundStyle(AS.text)
            .padding(.horizontal, 4)
            .frame(minWidth: size, minHeight: size, maxHeight: size)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(AS.controlFill))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.black.opacity(0.4)).frame(height: 1).padding(.horizontal, 3)
            }
    }
}

/// A shortcut as separate key caps: "⌃⌥V" → ⌃ ⌥ V, "⌥Tab" → ⌥ Tab.
public struct KeyCaps: View {
    let keys: [String]
    let text: String
    let spacing: CGFloat
    let size: CGFloat

    public init(_ shortcut: String, spacing: CGFloat = 2, size: CGFloat = 18) {
        keys = KeyCaps.split(shortcut)
        text = shortcut
        self.spacing = spacing
        self.size = size
    }

    /// A gesture described in words ("Select text in any app") isn't keys.
    public static func isProse(_ text: String) -> Bool {
        // "⌥ Tab" and "⌘ ⌘ hold" are keys; two or more words with letters are a sentence.
        text.split(separator: " ").filter { $0.contains(where: \.isLetter) }.count >= 2
    }

    public var body: some View {
        if Self.isProse(text) {
            Text(text).font(AS.font(11.5)).foregroundStyle(AS.textSecondary).lineLimit(1)
        } else {
            caps
        }
    }

    private var caps: some View {
        HStack(spacing: spacing) {
            ForEach(Array(keys.enumerated()), id: \.offset) { KeyCap($0.element, size: size) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.A11y.shortcut(KeySpeech.spoken(keys.joined())))
    }

    /// Modifier glyphs become their own caps; the rest of the text is one key.
    public static func split(_ text: String) -> [String] {
        let modifiers: Set<Character> = ["⌃", "⌥", "⇧", "⌘", "⇪"] // l10n-ignore
        var caps: [String] = []
        var rest = ""
        for character in text.replacingOccurrences(of: " ", with: "") {
            if modifiers.contains(character), rest.isEmpty { caps.append(String(character)) } else { rest.append(character) }
        }
        if !rest.isEmpty { caps.append(rest) }
        return caps
    }
}

// MARK: - Status

/// "Working" / "Allowed" with a green check, "Needs permission" in orange, "Off" in grey.
public struct ASStatusLabel: View {
    public enum Kind: Equatable { case good, warning, off, problem }
    let kind: Kind
    let text: String
    let fontSize: CGFloat

    public init(_ kind: Kind, _ text: String, fontSize: CGFloat = 12) {
        self.kind = kind
        self.text = text
        self.fontSize = fontSize
    }

    public init(_ badge: StatusBadge.Kind, fontSize: CGFloat = 11) {
        switch badge {
        case .working: self.init(.good, L10n.Status.working, fontSize: fontSize)
        case .needsPermission: self.init(.warning, L10n.Status.needsPermission, fontSize: fontSize)
        case .off: self.init(.off, L10n.Status.off, fontSize: fontSize)
        case let .problem(detail): self.init(.problem, L10n.Status.problem(detail), fontSize: fontSize)
        }
    }

    public var body: some View {
        HStack(spacing: fontSize <= 11 ? 4 : 5) {
            switch kind {
            case .good: LineIcon(ASIcon.checkCircle, size: fontSize, lineWidth: 2.2, color: AS.green)
            case .warning: LineIcon(ASIcon.warning, size: fontSize, lineWidth: 2, color: AS.orange)
            case .off: Circle().strokeBorder(AS.textTertiary, lineWidth: 1.4).frame(width: fontSize - 2, height: fontSize - 2)
            case .problem: LineIcon(ASIcon.warning, size: fontSize, lineWidth: 2, color: AS.red)
            }
            Text(text).lineLimit(1)
        }
        .font(.system(size: fontSize))
        .foregroundStyle(kind == .warning ? AS.orange : (kind == .off ? AS.textTertiary : AS.icon))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Grouped rows

/// The soft rounded card rows sit on.
public struct ASCard<Content: View>: View {
    let padding: CGFloat
    let radius: CGFloat
    let content: Content

    public init(padding: CGFloat = 0, radius: CGFloat = AS.cardRadius, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.radius = radius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(AS.cardFill))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(AS.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// A titled group: small grey title, a card of rows separated by hairlines,
/// and an optional footnote.
public struct ASSection<Content: View>: View {
    let title: String?
    let footer: String?
    let content: Content

    public init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title { ASSectionTitle(title) }
            ASCard { ASDividedStack { content } }
            if let footer { ASFootnote(footer) }
        }
    }
}

/// Small grey heading above a card.
public struct ASSectionTitle: View {
    let title: String
    let leading: CGFloat
    public init(_ title: String, leading: CGFloat = 12) {
        self.title = title
        self.leading = leading
    }

    public var body: some View {
        Text(title)
            .font(AS.sectionTitle)
            .foregroundStyle(AS.textSecondary)
            .padding(.leading, leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Grey explanatory text under a card.
public struct ASFootnote: View {
    let text: String
    let leading: CGFloat
    public init(_ text: String, leading: CGFloat = 12) {
        self.text = text
        self.leading = leading
    }

    public var body: some View {
        Text(text)
            .font(AS.footnote)
            .lineSpacing(2)
            .foregroundStyle(AS.textTertiary)
            .padding(.leading, leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Stacks rows with a hairline between each pair.
public struct ASDividedStack<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        _VariadicView.Tree(DividedLayout()) { content }
    }

    private struct DividedLayout: _VariadicView_MultiViewRoot {
        @ViewBuilder func body(children: _VariadicView.Children) -> some View {
            let last = children.last?.id
            VStack(spacing: 0) {
                ForEach(children) { child in
                    child
                    if child.id != last {
                        Rectangle().fill(AS.divider).frame(height: 1)
                    }
                }
            }
        }
    }
}

/// One row: optional icon, a title with an optional grey line under it,
/// and trailing controls.
public struct ASRow<Icon: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let icon: Icon
    let trailing: Trailing

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder icon: () -> Icon, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AS.body).foregroundStyle(AS.text)
                if let subtitle {
                    Text(subtitle).font(AS.footnote).foregroundStyle(AS.textTertiary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, subtitle == nil ? 6 : 8)
        .frame(minHeight: Icon.self == EmptyView.self && subtitle == nil ? 44 : 52)
    }
}

public extension ASRow where Icon == EmptyView {
    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title, subtitle: subtitle, icon: { EmptyView() }, trailing: trailing)
    }
}

public extension ASRow where Icon == EmptyView, Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle, icon: { EmptyView() }, trailing: { EmptyView() })
    }
}

/// A row with a switch on the right.
public struct ASToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    public init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        _isOn = isOn
    }

    public var body: some View {
        ASRow(title, subtitle: subtitle) { ASSwitch(title, isOn: $isOn) }
    }
}

// MARK: - Page chrome

/// The illustration area at the top of a feature page: a dark stage with a
/// soft colored light from the top.
public struct ASStage<Content: View>: View {
    let tint: Color
    let height: CGFloat
    let content: Content

    public init(tint: Color, height: CGFloat = 164, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.height = height
        self.content = content()
    }

    public var body: some View {
        ZStack {
            AS.stage
            EllipticalGradient(colors: [tint.opacity(0.30), tint.opacity(0)], center: .top, startRadiusFraction: 0, endRadiusFraction: 0.7)
                .scaleEffect(x: 1.4, y: 1.8, anchor: .top)
            content
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AS.tileRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AS.tileRadius, style: .continuous).strokeBorder(AS.tileBorder, lineWidth: 1))
    }
}

public extension View {
    /// The All Set window look: dark, SF Pro, light text.
    func allSetWindowStyle() -> some View {
        environment(\.colorScheme, .dark)
            .foregroundStyle(AS.text)
            .tint(AS.blue)
    }
}

// MARK: - Shortcut editing inside feature pages

/// Set by the app on feature pages: returns a click-to-record shortcut
/// control for a hotkey action ID. Lets a feature lay out its own
/// shortcut grid (Window Layouts) while the app owns rebinding.
public struct ShortcutEditorKey: EnvironmentKey {
    public static let defaultValue: (@MainActor @Sendable (String) -> AnyView)? = nil
}

public extension EnvironmentValues {
    var shortcutEditor: (@MainActor @Sendable (String) -> AnyView)? {
        get { self[ShortcutEditorKey.self] }
        set { self[ShortcutEditorKey.self] = newValue }
    }
}

// MARK: - Logo

/// The All Set mark: a letter A whose crossbar is a cobalt checkmark, on a
/// graphite tile (design: "App icon A, polished", 512 grid).
public struct AllSetLogo: View {
    let size: CGFloat

    public init(size: CGFloat) { self.size = size }

    nonisolated private static let letter = "M150 392L256 124L362 392"
    nonisolated private static let check = "M212 296l40 40 84-96"

    public var body: some View {
        let k = size / 512
        let tile = RoundedRectangle(cornerRadius: 115 * k, style: .continuous)
        ZStack {
            tile.fill(LinearGradient(colors: [Color(hex: 0x363A47), Color(hex: 0x171A20)], startPoint: .top, endPoint: .bottom))
            tile.fill(RadialGradient(colors: [AS.accent.opacity(0.70), AS.accent.opacity(0)],
                                     center: UnitPoint(x: 0.86, y: 0.98), startRadius: 0, endRadius: size * 0.8 * 0.7))
            tile.fill(RadialGradient(colors: [Color.white.opacity(0.26), Color.white.opacity(0)],
                                     center: UnitPoint(x: 0.18, y: 0), startRadius: 0, endRadius: size * 0.58))
            tile.strokeBorder(Color.white.opacity(0.16), lineWidth: max(0.5, 4 * k))
            LetterShape().fill(Color(hex: 0xF7F6F2))
            SVGPath(Self.check, viewBox: 512)
                .stroke(AS.accent, style: StrokeStyle(lineWidth: 40 * k, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The A's outline with a gap cut around the checkmark.
    private struct LetterShape: Shape {
        func path(in rect: CGRect) -> Path {
            let k = rect.width / 512
            let round = { (w: CGFloat) in StrokeStyle(lineWidth: w * k, lineCap: .round, lineJoin: .round) }
            let letter = SVGPath(AllSetLogo.letter, viewBox: 512).path(in: rect).strokedPath(round(56))
            let gap = SVGPath(AllSetLogo.check, viewBox: 512).path(in: rect).strokedPath(round(72))
            return letter.subtracting(gap)
        }
    }
}
