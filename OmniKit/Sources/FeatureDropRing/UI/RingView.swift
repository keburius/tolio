import AppKit
import OmniCore
import OmniPlatform
import SwiftUI
import UniformTypeIdentifiers

/// What the ring shows right now.
@MainActor
@Observable
final class RingModel {
    var items: [RingItem] = []
    var layout = RingLayout(count: 0, orbSize: 72, center: .zero, bounds: .zero)
    var hovered: RingItem.ID?
    var appeared = false
    var cargoCount = 0
    var glass = true

    @ObservationIgnored var title: (RingItem) -> String = { _ in "" }
    @ObservationIgnored var actionTitle: (RingItem) -> String = { _ in "" }
    @ObservationIgnored var icon: (RingItem) -> NSImage? = { _ in nil }
    @ObservationIgnored var onDrop: (RingItem, [URL]) -> Void = { _, _ in }
    @ObservationIgnored var onClick: (RingItem) -> Void = { _ in }
    @ObservationIgnored var onDismiss: () -> Void = {}
}

struct RingView: View {
    let model: RingModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Nearly invisible, but catches clicks: clicking empty space closes the ring.
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .onTapGesture { model.onDismiss() }
            centerLabel
            ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                if model.layout.positions.indices.contains(index) {
                    let target = model.layout.positions[index]
                    let point = model.appeared || OmniStyle.reduceMotion ? target : model.layout.center
                    OrbView(model: model, item: item)
                        .position(point)
                        .scaleEffect(model.appeared || OmniStyle.reduceMotion ? 1 : 0.3, anchor: .center)
                        .opacity(model.appeared || OmniStyle.reduceMotion ? 1 : 0)
                        .animation(
                            OmniStyle.motion(.spring(response: 0.38, dampingFraction: 0.72).delay(Double(index) * 0.018)),
                            value: model.appeared
                        )
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var centerLabel: some View {
        let hovered = model.items.first { $0.id == model.hovered }
        Group {
            if model.items.isEmpty {
                label(L10n.DropRing.empty, strong: true)
            } else if let hovered {
                label(model.actionTitle(hovered), strong: true)
            } else {
                label(L10n.DropRing.hint, strong: false)
            }
        }
        .position(model.layout.center)
        .opacity(model.appeared || OmniStyle.reduceMotion ? 1 : 0)
        .animation(OmniStyle.motion(), value: model.hovered)
    }

    private func label(_ text: String, strong: Bool) -> some View {
        Text(text)
            .font(strong ? .callout.weight(.semibold) : .caption.weight(.medium))
            .foregroundStyle(strong ? Color.white : Color.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(strong ? Color.accentColor.opacity(0.92) : Color.black.opacity(0.45)))
            .frame(maxWidth: model.layout.radius * 1.5)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One circle: its icon on a glass or solid disc, with a small badge.
private struct OrbView: View {
    let model: RingModel
    let item: RingItem
    @State private var targeted = false

    var body: some View {
        let size = model.layout.orbSize
        let active = model.hovered == item.id
        ZStack {
            Circle()
                .fill(model.glass ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(white: 0.14).opacity(0.94)))
                .overlay(Circle().fill(Color.accentColor.opacity(active ? 0.28 : 0)))
                .overlay(Circle().strokeBorder(Color.white.opacity(active ? 0.9 : 0.22), style: StrokeStyle(lineWidth: active ? 2 : 1, dash: active ? [5, 4] : [])))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            content(size: size)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) { badge(size: size) }
        .scaleEffect(active && !OmniStyle.reduceMotion ? 1.14 : 1)
        .animation(OmniStyle.motion(.spring(response: 0.25, dampingFraction: 0.7)), value: active)
        .contentShape(Circle())
        .onHover { inside in
            if inside { model.hovered = item.id } else if model.hovered == item.id { model.hovered = nil }
        }
        .onTapGesture { model.onClick(item) }
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { targeted }, set: { value in
            targeted = value
            if value { model.hovered = item.id } else if model.hovered == item.id { model.hovered = nil }
        })) { providers in
            Task { @MainActor in
                let urls = await Self.load(providers)
                if !urls.isEmpty { model.onDrop(item, urls) }
            }
            return true
        }
        .help(model.title(item))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.actionTitle(item))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private func content(size: CGFloat) -> some View {
        switch item.kind {
        case let .contact(name, _, _):
            Text(RingItem.initials(name))
                .font(.system(size: size * 0.3, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size * 0.66, height: size * 0.66)
                .background(Circle().fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.42)], startPoint: .top, endPoint: .bottom)))
        case .cargo:
            Image(systemName: "shippingbox").font(.system(size: size * 0.38, weight: .regular)).foregroundStyle(.white)
        default:
            if let image = model.icon(item) {
                Image(nsImage: image).resizable().interpolation(.high).frame(width: size * 0.62, height: size * 0.62)
            } else {
                Image(systemName: "questionmark").font(.system(size: size * 0.3)).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder private func badge(size: CGFloat) -> some View {
        let d = max(18, size * 0.3)
        switch item.kind {
        case let .folder(_, mode):
            badgeCircle(mode == .move ? "arrow.right" : "plus", .blue, d)
        case let .contact(_, _, channel):
            badgeCircle(channel == .mail ? "envelope.fill" : "message.fill", channel == .mail ? .blue : .green, d)
        case .shortcut:
            badgeCircle("sparkles", .purple, d)
        case .cargo where model.cargoCount > 0:
            Text("\(model.cargoCount)")
                .font(.system(size: d * 0.55, weight: .bold, design: .rounded)).foregroundStyle(.white)
                .frame(minWidth: d, minHeight: d)
                .background(Circle().fill(.red))
        default:
            EmptyView()
        }
    }

    private func badgeCircle(_ symbol: String, _ color: Color, _ d: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: d * 0.48, weight: .bold)).foregroundStyle(.white)
            .frame(width: d, height: d)
            .background(Circle().fill(color).overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5)))
    }

    /// File URLs from a drop.
    static func load(_ providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let url: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
            }
            if let url, url.isFileURL { urls.append(url) }
        }
        return urls
    }
}
