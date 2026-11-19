import OmniCore
import OmniPlatform
import SwiftUI

/// First page: how many features are on, a slideshow of what All Set does,
/// the most-loved features as cards and the rest as compact rows.
struct OverviewPane: View {
    let services: AppServices
    let navigation: SettingsNavigation

    /// Shown as large cards, in this order; every other feature is a row.
    static let mostLoved: [FeatureID] = ["clipboard", "island", "dropring", "deskminder", "keepawake", "windows", "screenshots", "keyboardclean"]

    private var features: [any Feature] { services.sidebarFeatures(includingHidden: navigation.showsHiddenFeatures) }

    var body: some View {
        let loved = Self.mostLoved.compactMap { id in features.first { $0.id == id } }
        let others = features.filter { !Self.mostLoved.contains($0.id) }
        PageScaffold(L10n.SettingsUI.overview, spacing: 12) {
            onSummary
        } content: {
            Slideshow(services: services)
            VStack(alignment: .leading, spacing: 12) {
                if !loved.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ASSectionTitle(L10n.AllSet.mostLoved, leading: 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(loved, id: \.id) { feature in
                                FeatureCard(feature: feature, services: services) { navigation.open(.feature(feature.id)) }
                            }
                        }
                    }
                }
                if !others.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ASSectionTitle(L10n.AllSet.moreFeatures, leading: 4)
                        let half = (others.count + 1) / 2
                        HStack(alignment: .top, spacing: 12) {
                            CompactList(features: Array(others.prefix(half)), services: services, navigation: navigation)
                            CompactList(features: Array(others.dropFirst(half)), services: services, navigation: navigation)
                        }
                    }
                }
            }
        }
    }

    /// A colored bar per feature that's on, and "12 of 14 on".
    private var onSummary: some View {
        let on = features.filter { services.features.isWanted($0.id) }
        return HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(features, id: \.id) { feature in
                    let isOn = services.features.isWanted(feature.id)
                    Capsule()
                        .fill(isOn ? (FeatureLook.of(feature.id)?.ink ?? AS.icon) : Color.white.opacity(0.14))
                        .frame(width: 14, height: 5)
                }
            }
            .accessibilityHidden(true)
            Text(L10n.AllSet.onCount(on.count, features.count))
                .font(AS.font(12, .semibold))
                .monospacedDigit()
                .foregroundStyle(AS.icon)
        }
    }
}

// MARK: - Slideshow

/// Five slides that change every 6 seconds (not with Reduce Motion).
private struct Slideshow: View {
    let services: AppServices
    @State private var index = 0
    private let count = 5

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            slide(index)
                .id(index)
                .transition(.opacity)
            controls.padding(.trailing, 14).padding(.bottom, 12)
        }
        .frame(height: 108)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AS.tileBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 0)
        .task {
            guard !OmniStyle.reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                if Task.isCancelled { break }
                step(1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.AllSet.aboutTitle)
    }

    private func step(_ by: Int) {
        withAnimation(OmniStyle.motion(.easeInOut(duration: 0.35))) { index = (index + by + count) % count }
    }

    @ViewBuilder private func slide(_ i: Int) -> some View {
        switch i {
        case 0:
            SlideContent(tint: Color(hex: 0x8E8E93), title: L10n.AllSet.appName, body: Text(L10n.AllSet.aboutBody)) {
                AllSetLogo(size: 64)
            }
        case 1:
            SlideContent(tint: Color(hex: 0x007AFF), title: L10n.AllSet.slideClipboardTitle,
                         body: keyText(L10n.AllSet.slideClipboardBody, shortcut(of: "clipboard", fallback: "⌃⌥V"))) { // l10n-ignore
                FeatureIcon("clipboard", size: 64)
            }
        case 2:
            SlideContent(tint: Color(hex: 0x32ADE6), title: L10n.AllSet.slideDropRingTitle, body: Text(L10n.AllSet.slideDropRingBody)) {
                FeatureIcon("dropring", size: 64)
            }
        case 3:
            SlideContent(tint: Color(hex: 0xFF3B30), title: L10n.AllSet.slideScreenshotTitle,
                         body: keyText(L10n.AllSet.slideScreenshotBody, shortcut(of: "screenshots", fallback: "⇧⌘4"))) { // l10n-ignore
                FeatureIcon("screenshots", size: 64)
            }
        default:
            SlideContent(tint: Color(hex: 0xFF9500), title: L10n.AllSet.slideMinderTitle, body: Text(L10n.AllSet.slideMinderBody)) {
                FeatureIcon("deskminder", size: 64)
            }
        }
    }

    private func shortcut(of id: FeatureID, fallback: String) -> String {
        services.features.feature(id).flatMap { services.mainShortcutText(of: $0) } ?? fallback
    }

    /// The sentence with the shortcut drawn as key caps where `%@` is.
    private func keyText(_ make: (String) -> String, _ keys: String) -> Text {
        let marker = "\u{1}"
        let parts = make(marker).components(separatedBy: marker)
        guard parts.count == 2 else { return Text(make(keys)) }
        return Text(parts[0]) + InlineKeyCaps.text(keys) + Text(parts[1])
    }

    private var controls: some View {
        HStack(spacing: 10) {
            roundButton(ASIcon.chevronLeft, L10n.AllSet.previousSlide) { step(-1) }
            HStack(spacing: 5) {
                ForEach(0 ..< count, id: \.self) { i in
                    Button {
                        withAnimation(OmniStyle.motion(.easeInOut(duration: 0.35))) { index = i }
                    } label: {
                        Capsule().fill(i == index ? Color.white : Color.white.opacity(0.28))
                            .frame(width: i == index ? 16 : 6, height: 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.AllSet.slideNumber(i + 1, count))
                    .accessibilityAddTraits(i == index ? .isSelected : [])
                }
            }
            roundButton(ASIcon.chevronRight, L10n.AllSet.nextSlide) { step(1) }
        }
    }

    private func roundButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LineIcon(icon, size: 12, lineWidth: 2, color: AS.text)
                .frame(width: 24, height: 24)
                .background(Circle().fill(AS.controlFill))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct SlideContent<Icon: View>: View {
    let tint: Color
    let title: String
    let body_: Text
    let icon: Icon

    init(tint: Color, title: String, body: Text, @ViewBuilder icon: () -> Icon) {
        self.tint = tint
        self.title = title
        body_ = body
        self.icon = icon()
    }

    var body: some View {
        HStack(spacing: 18) {
            icon
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(AS.heroTitle).tracking(-0.2).foregroundStyle(AS.text)
                body_.font(AS.body).lineSpacing(3).foregroundStyle(AS.textBody).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 20)
        .padding(.trailing, 150)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GeometryReader { proxy in
                EllipticalGradient(colors: [tint.opacity(0.24), tint.opacity(0)], center: .leading, startRadiusFraction: 0, endRadiusFraction: 1)
                    .frame(width: proxy.size.width * 1.1, height: proxy.size.height * 3)
                    .offset(x: -proxy.size.width * 0.55, y: -proxy.size.height)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Key caps that flow inside a sentence (rendered once into an image).
@MainActor
enum InlineKeyCaps {
    static func text(_ keys: String) -> Text {
        let renderer = ImageRenderer(content: KeyCaps(keys).environment(\.colorScheme, .dark))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return Text(keys) }
        return Text(Image(nsImage: image)).baselineOffset(-4)
            .accessibilityLabel(L10n.A11y.shortcut(KeySpeech.spoken(keys)))
    }
}

// MARK: - Cards

/// A most-loved feature: icon and switch, name and tagline, shortcut and status.
private struct FeatureCard: View {
    let feature: any Feature
    let services: AppServices
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        let status = services.features.status(of: feature.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                FeatureIcon(feature.id, size: 44, fallbackSymbol: feature.symbolName)
                Spacer()
                ASSwitch(feature.displayName, isOn: Binding(
                    get: { services.features.isWanted(feature.id) },
                    set: { services.features.setWanted($0, for: feature.id) }
                ))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(feature.displayName)
                    .font(AS.font(13.5, .semibold)).tracking(-0.1)
                    .foregroundStyle(AS.text).lineLimit(1)
                Text(feature.tagline)
                    .font(AS.font(12)).lineSpacing(2)
                    .foregroundStyle(AS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack {
                if let shortcut = services.mainShortcutText(of: feature), !KeyCaps.isProse(shortcut) { KeyCaps(shortcut) }
                Spacer(minLength: 4)
                ASStatusLabel(status.badge)
            }
        }
        .padding(12)
        .frame(height: 164)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(hovering ? Color.white.opacity(0.07) : AS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(hovering ? Color.white.opacity(0.14) : AS.tileBorder, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering = $0 }
        .animation(OmniStyle.motion(), value: hovering)
        .onTapGesture(perform: open)
        .help(L10n.SettingsUI.openSettingsHint)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(feature.displayName), open)
    }
}

/// The remaining features as 34 pt rows in a card.
private struct CompactList: View {
    let features: [any Feature]
    let services: AppServices
    let navigation: SettingsNavigation

    var body: some View {
        ASCard {
            ASDividedStack {
                ForEach(features, id: \.id) { feature in
                    HStack(spacing: 10) {
                        FeatureIcon(feature.id, size: 26, fallbackSymbol: feature.symbolName)
                        Text(feature.displayName)
                            .font(AS.font(13, .medium)).foregroundStyle(AS.text).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let shortcut = services.mainShortcutText(of: feature), !KeyCaps.isProse(shortcut) { KeyCaps(shortcut) }
                        ASSwitch(feature.displayName, isOn: Binding(
                            get: { services.features.isWanted(feature.id) },
                            set: { services.features.setWanted($0, for: feature.id) }
                        ))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                    .onTapGesture { navigation.open(.feature(feature.id)) }
                    .help(L10n.SettingsUI.openSettingsHint)
                }
            }
        }
    }
}
