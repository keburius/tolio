import AppKit
import OmniCore
import OmniPlatform
import SwiftUI
import UniformTypeIdentifiers

/// The Tray: drop files on the notch to keep them handy, drag them out
/// anywhere, or send them with AirDrop.
struct TrayPage: View {
    let model: IslandModel
    @Environment(\.islandActions) private var actions
    @State private var overFiles = false
    @State private var overAirDrop = false
    @State private var selection: Set<UUID> = []

    private var tray: TrayStore { model.services.tray }

    var body: some View {
        HStack(spacing: 10) {
            airDropZone.frame(width: 118)
            filesZone
        }
        .onChange(of: overFiles || overAirDrop) { _, over in model.dropTargeted = over }
    }

    // MARK: AirDrop

    private var airDropZone: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Color(red: 0.2, green: 0.55, blue: 1).opacity(overAirDrop ? 0.5 : 0.22)).frame(width: 46, height: 46)
                Image(systemName: "dot.radiowaves.up.forward").font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.75, blue: 1))
                    .symbolEffect(.variableColor.iterative, isActive: overAirDrop && !OmniStyle.reduceMotion)
            }
            .scaleEffect(overAirDrop ? 1.12 : 1)
            Text(L10n.Island.airDrop).font(.system(size: 11.5, weight: .semibold))
            Text(L10n.Island.airDropHint).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(zoneBackground(highlighted: overAirDrop, tint: .blue))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            let chosen = chosenURLs
            if !chosen.isEmpty { model.services.airDrop(chosen) }
        }
        .help(L10n.Island.airDropHelp)
        .onDrop(of: [.fileURL], isTargeted: $overAirDrop) { providers in
            Self.loadURLs(providers) { urls in model.services.airDrop(urls) }
            return true
        }
        .animation(OmniStyle.motion(.spring(response: 0.3, dampingFraction: 0.6)), value: overAirDrop)
    }

    // MARK: Files

    private var chosenURLs: [URL] {
        let ids = selection.isEmpty ? Set(tray.items.map(\.id)) : selection
        return tray.items.filter { ids.contains($0.id) }.compactMap { tray.urls[$0.id] }
    }

    private var filesZone: some View {
        VStack(spacing: 6) {
            if tray.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: overFiles ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                        .font(.system(size: 22, weight: .medium))
                        .symbolEffect(.bounce, value: overFiles)
                    Text(L10n.Island.trayEmpty).font(.system(size: 12, weight: .semibold))
                    Text(L10n.Island.trayEmptyHint).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 6) {
                    CardTitle(text: L10n.Island.trayPage, symbol: "tray.full.fill",
                              trailing: selection.isEmpty ? L10n.Island.items(tray.items.count) : L10n.Island.selected(selection.count))
                    // Drag everything (or the selection) out in one go.
                    ZStack {
                        Label(L10n.Island.dragAll, systemImage: "hand.draw").font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8).frame(height: 20)
                            .background(Capsule().fill(.white.opacity(0.12)))
                        FileDragSource(urls: chosenURLs) { dropped in
                            if dropped && actions.removesAfterDrag() { removeChosen() }
                        }
                    }
                    .fixedSize()
                    .help(L10n.Island.dragAllHelp)
                    BandButton(symbol: "square.and.arrow.up", label: L10n.Island.share) { model.services.share(chosenURLs, nil) }
                    BandButton(symbol: "trash", label: selection.isEmpty ? L10n.Island.clearTray : L10n.Island.removeSelected) { removeChosen() }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tray.items) { item in
                            if let url = tray.urls[item.id] {
                                TrayTile(url: url, thumbnails: model.services.thumbnails, selected: selection.contains(item.id)) {
                                    toggleSelection(item.id)
                                } onDragEnd: { dropped in
                                    if dropped && actions.removesAfterDrag() { tray.remove([item.id]) }
                                }
                                .contextMenu { menu(for: item, url: url) }
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .animation(OmniStyle.motion(.spring(response: 0.35, dampingFraction: 0.7)), value: tray.items.map(\.id))
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(zoneBackground(highlighted: overFiles, tint: .white))
        .onDrop(of: [.fileURL, .utf8PlainText, .png, .tiff], isTargeted: $overFiles) { providers in
            accept(providers)
            return true
        }
    }

    private func zoneBackground(highlighted: Bool, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.white.opacity(highlighted ? 0.14 : 0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(highlighted ? tint.opacity(0.8) : .white.opacity(0.1), style: StrokeStyle(lineWidth: highlighted ? 1.5 : 1, dash: [6, 4]))
            )
            .animation(OmniStyle.motion(), value: highlighted)
    }

    @ViewBuilder private func menu(for item: TrayItem, url: URL) -> some View {
        Button(L10n.Island.open) { NSWorkspace.shared.open(url) }
        Button(L10n.Island.showInFinder) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        Button(L10n.Island.copyPath) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
        Divider()
        Button(L10n.Island.airDrop) { model.services.airDrop([url]) }
        Button(L10n.Island.share) { model.services.share([url], nil) }
        Divider()
        Button(L10n.Island.removeFromTray) {
            tray.remove([item.id])
            selection.remove(item.id)
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func removeChosen() {
        if selection.isEmpty { tray.clear() } else { tray.remove(selection) }
        selection = []
    }

    // MARK: Dropping

    private func accept(_ providers: [NSItemProvider]) {
        let tray = tray
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                Self.loadURLs([provider]) { tray.add($0) }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier)
                        || provider.hasItemConformingToTypeIdentifier(UTType.tiff.identifier) {
                let type = provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) ? UTType.png : UTType.tiff
                _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    guard let data, let png = Self.png(data) else { return }
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { _ = tray.addImage(png, name: L10n.Island.droppedImage) }
                    }
                }
            } else if provider.canLoadObject(ofClass: String.self) {
                _ = provider.loadObject(ofClass: String.self) { text, _ in
                    guard let text, !text.isEmpty else { return }
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { _ = tray.addText(text, name: Self.textName(text)) }
                    }
                }
            }
        }
        AppFeel.tap(.levelChange)
    }

    /// File URLs from drop providers, delivered together on the main thread.
    static func loadURLs(_ providers: [NSItemProvider], then: @escaping @MainActor ([URL]) -> Void) {
        let group = DispatchGroup()
        let box = URLBox()
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.isFileURL { box.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            MainActor.assumeIsolated {
                let urls = box.urls
                if !urls.isEmpty { then(urls) }
            }
        }
    }

    /// Collects URLs from several loading callbacks.
    final class URLBox: @unchecked Sendable {
        private let lock = NSLock()
        private var list: [URL] = []
        func append(_ url: URL) { lock.lock(); list.append(url); lock.unlock() }
        var urls: [URL] { lock.lock(); defer { lock.unlock() }; return list }
    }

    nonisolated static func png(_ data: Data) -> Data? {
        guard let rep = NSBitmapImageRep(data: data) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// The first few words of dropped text, as a file name.
    nonisolated static func textName(_ text: String) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).prefix(5).joined(separator: " ")
        let cleaned = words.filter { !"/:\\?*\"<>|".contains($0) }
        return cleaned.isEmpty ? "Text" : String(cleaned.prefix(40)) // l10n-ignore
    }
}

/// One file: its preview and name. Drag it out; click to select;
/// double-click to open.
private struct TrayTile: View {
    let url: URL
    let thumbnails: Thumbnails
    let selected: Bool
    let onSelect: () -> Void
    let onDragEnd: (Bool) -> Void
    @State private var hover = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Image(nsImage: thumbnails.image(for: url)).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                FileDragSource(urls: [url], onClick: { count in
                    if count >= 2 { NSWorkspace.shared.open(url) } else { onSelect() }
                }, onEnd: onDragEnd)
            }
            .frame(width: 60, height: 56)
            Text(url.lastPathComponent).font(.system(size: 9.5, weight: .medium)).lineLimit(2)
                .multilineTextAlignment(.center).truncationMode(.middle)
                .frame(width: 70, height: 26, alignment: .top)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.45) : .white.opacity(hover ? 0.1 : 0)))
        .scaleEffect(hover && !OmniStyle.reduceMotion ? 1.04 : 1)
        .onHover { hover = $0 }
        .simultaneousGesture(TapGesture(count: 2).onEnded { NSWorkspace.shared.open(url) })
        .simultaneousGesture(TapGesture().onEnded(onSelect))
        .animation(OmniStyle.motion(.spring(response: 0.25, dampingFraction: 0.7)), value: hover)
        .help(url.path)
        .accessibilityLabel(url.lastPathComponent)
    }
}

/// Starts a drag of one or several files (SwiftUI's `onDrag` handles one,
/// and only inside the app's own windows reliably).
struct FileDragSource: NSViewRepresentable {
    let urls: [URL]
    var onClick: (_ clickCount: Int) -> Void = { _ in }
    let onEnd: (_ dropped: Bool) -> Void

    func makeNSView(context: Context) -> FileDragView { FileDragView() }

    func updateNSView(_ view: FileDragView, context: Context) {
        view.urls = urls
        view.onEnd = onEnd
        view.onClick = onClick
    }
}

final class FileDragView: NSView, NSDraggingSource {
    var urls: [URL] = []
    var onEnd: (Bool) -> Void = { _ in }
    var onClick: (Int) -> Void = { _ in }
    private var downEvent: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downEvent = event
    }

    override func mouseUp(with event: NSEvent) {
        // A click without a drag.
        if downEvent != nil { onClick(event.clickCount) }
        downEvent = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard !urls.isEmpty, let downEvent else { return }
        let start = convert(downEvent.locationInWindow, from: nil)
        let current = convert(event.locationInWindow, from: nil)
        guard hypot(current.x - start.x, current.y - start.y) > 3 else { return }
        self.downEvent = nil
        let items = urls.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let offset = CGFloat(min(index, 4)) * 5
            item.setDraggingFrame(NSRect(x: start.x - 24 + offset, y: start.y - 24 - offset, width: 48, height: 48), contents: icon)
            return item
        }
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .generic, .link] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onEnd(operation != [])
    }
}
