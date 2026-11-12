import AppKit
import SwiftUI

/// Grid of window tiles with thumbnails (or app icons) and titles.
struct SwitcherView: View {
    @Bindable var model: SwitcherModel

    static let tileSize = CGSize(width: 220, height: 176)
    static let spacing: CGFloat = 10
    static let padding: CGFloat = 16

    /// Overlay size that fits `count` tiles within `maxSize`.
    static func size(for count: Int, maxSize: CGSize) -> CGSize {
        let fitColumns = max(1, Int((maxSize.width - 2 * padding + spacing) / (tileSize.width + spacing)))
        let columns = max(1, min(count, fitColumns))
        let rows = max(1, Int(ceil(Double(count) / Double(columns))))
        let width = CGFloat(columns) * tileSize.width + CGFloat(columns - 1) * spacing + 2 * padding
        let height = CGFloat(rows) * tileSize.height + CGFloat(rows - 1) * spacing + 2 * padding
        return CGSize(width: width, height: min(height, maxSize.height))
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = max(1, Int((geometry.size.width - 2 * Self.padding + Self.spacing) / (Self.tileSize.width + Self.spacing)))
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(Self.tileSize.width), spacing: Self.spacing), count: columns),
                        spacing: Self.spacing
                    ) {
                        ForEach(Array(model.records.enumerated()), id: \.element.id) { index, record in
                            WindowTile(record: record, isSelected: index == model.selection, model: model)
                                .id(record.id)
                                .onTapGesture { model.onClick(index) }
                        }
                    }
                    .padding(Self.padding)
                }
                .scrollIndicators(.never)
                .onChange(of: model.selection) { _, selection in
                    if model.records.indices.contains(selection) { proxy.scrollTo(model.records[selection].id) }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct WindowTile: View {
    let record: WindowRecord
    let isSelected: Bool
    let model: SwitcherModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                preview
                    .frame(width: 196, height: 118)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .opacity(record.state == .normal ? 1 : 0.55)
                Image(nsImage: appIcon).resizable().frame(width: 28, height: 28).offset(x: -6, y: 6)
            }
            .frame(width: 196, height: 118)
            Text(record.title).font(.callout.weight(.medium)).lineLimit(1)
            HStack(spacing: 4) {
                Text(record.appName).lineLimit(1)
                if let badge { Text("· \(badge)") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: SwitcherView.tileSize.width, height: SwitcherView.tileSize.height, alignment: .topLeading)
        .background(isSelected ? Color.accentColor.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
        .contentShape(Rectangle())
    }

    @ViewBuilder private var preview: some View {
        let _ = model.thumbnailRevision
        if let image = model.thumbnail(record.id) {
            Image(decorative: image, scale: 2).resizable().aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                Color.secondary.opacity(0.12)
                Image(nsImage: appIcon).resizable().frame(width: 56, height: 56)
            }
        }
    }

    private var appIcon: NSImage {
        NSRunningApplication(processIdentifier: record.pid)?.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }

    private var badge: String? {
        switch record.state {
        case .normal: nil
        case .minimized: "Minimized"
        case .hidden: "Hidden"
        case .otherSpace: "Other Space"
        }
    }
}
