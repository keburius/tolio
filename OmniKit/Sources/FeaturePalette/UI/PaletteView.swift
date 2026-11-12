import AppKit
import SwiftUI

/// Search field plus result list. Keyboard handling lives in `PaletteController`.
struct PaletteView: View {
    @Bindable var model: PaletteViewModel
    let onActivate: (Int) -> Void
    @FocusState private var fieldFocused: Bool

    static let width: CGFloat = 680
    static let headerHeight: CGFloat = 56
    static let rowHeight: CGFloat = 46
    static let maxVisibleRows = 8

    /// Height that fits `count` results without scrolling (up to the max).
    static func height(forResults count: Int) -> CGFloat {
        let rows = min(count, maxVisibleRows)
        return headerHeight + (rows > 0 ? CGFloat(rows) * rowHeight + 13 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
                TextField("Search apps, settings, commands — or 2+2, 5 km in mi, 20 usd, clip …", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($fieldFocused)
            }
            .padding(.horizontal, 16)
            .frame(height: Self.headerHeight)

            if !model.results.isEmpty {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, item in
                                PaletteRow(item: item, isSelected: index == model.selection)
                                    .id(item.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onActivate(index) }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: model.selection) { _, selection in
                        guard model.results.indices.contains(selection) else { return }
                        proxy.scrollTo(model.results[selection].id)
                    }
                }
            }
        }
        .frame(width: Self.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.separator.opacity(0.5)))
        .onChange(of: model.focusRequest, initial: true) { fieldFocused = true }
    }
}

private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(highlightedTitle).lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(item.kindLabel).font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .frame(height: PaletteView.rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var icon: some View {
        switch item.icon {
        case let .file(url):
            Image(nsImage: IconCache.icon(for: url))
                .resizable()
        case let .symbol(name):
            Image(systemName: name).font(.title2).foregroundStyle(Color.accentColor)
        case let .image(url):
            Image(nsImage: IconCache.thumbnail(for: url))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var highlightedTitle: AttributedString {
        let matched = Set(item.highlighted)
        var result = AttributedString()
        for (offset, character) in item.title.enumerated() {
            var piece = AttributedString(String(character))
            if matched.contains(offset) { piece.font = .body.bold() }
            result += piece
        }
        if item.kind == .answer { result.font = .title3.weight(.semibold) }
        return result
    }
}

/// File icons, loaded once per path.
@MainActor
enum IconCache {
    private static let cache = NSCache<NSURL, NSImage>()

    static func icon(for url: URL) -> NSImage {
        if let image = cache.object(forKey: url as NSURL) { return image }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 32, height: 32)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Small image files (thumbnails written by features), cached.
    static func thumbnail(for url: URL) -> NSImage {
        if let image = cache.object(forKey: url as NSURL) { return image }
        let image = NSImage(contentsOf: url) ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil) ?? NSImage()
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
