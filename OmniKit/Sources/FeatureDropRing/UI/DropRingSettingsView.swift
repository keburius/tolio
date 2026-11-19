import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

extension DropRingFeature {
    public var settingsEntries: [SettingsEntry] {
        [
            SettingsEntry(anchor: Anchor.circles, label: L10n.DropRing.circles, keywords: ["folder", "app", "contact", "person", "shortcut", "cargo", "trash", "drop"]),
            SettingsEntry(anchor: Anchor.shake, label: L10n.DropRing.shake, keywords: ["mouse", "shake", "pointer", "sensitivity"]),
            SettingsEntry(anchor: Anchor.size, label: L10n.DropRing.size, keywords: ["appearance", "glass", "look", "theme"]),
        ]
    }

    public var tagline: String { L10n.DropRing.tagline }

    public func makeSettingsHero() -> AnyView? { AnyView(DropRingHero()) }
}

// MARK: - Hero

/// Seven circles around the pointer while a file is dragged; Desktop is lit.
private struct DropRingHero: View {
    private static let folder = "M1.8 4.2h5.5l2.4 2.4h8.6v9.2h-16.5z"
    private static let cargo = "M2.5 3.5h15v13h-15zM2.5 8.2h15M7.7 11.8h4.6"
    private static let trash = "M3 4.8h14M5.2 4.8l1.2 11.7h7.2l1.2-11.7M7.7 2.4h4.6"
    private static let chat = "M2 3.6h16v10.4h-9.2l-4 3.4v-3.4h-2.8z"

    private static let circles: [(x: CGFloat, y: CGFloat, icon: String)] = [
        (215.3, 45.8, folder), (226.5, 94.9, folder), (195.2, 134.3, cargo),
        (144.8, 134.3, trash), (113.5, 94.9, chat), (124.7, 45.8, chat),
    ]

    var body: some View {
        ASStage(tint: Color(hex: 0x32ADE6)) {
            ZStack(alignment: .topLeading) {
                // The highlighted circle with its dashed ring.
                Circle().fill(Color(hex: 0x32ADE6)).frame(width: 38, height: 38).position(x: 170, y: 24)
                Circle().stroke(.white, style: StrokeStyle(lineWidth: 1.8, dash: [4.5, 4.5])).frame(width: 46, height: 46).position(x: 170, y: 24)
                icon(Self.folder).position(x: 170, y: 24)
                ForEach(Array(Self.circles.enumerated()), id: \.offset) { _, circle in
                    Circle().fill(Color(hex: 0x15161B)).frame(width: 38, height: 38).position(x: circle.x, y: circle.y)
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 1.2).frame(width: 38, height: 38).position(x: circle.x, y: circle.y)
                    icon(circle.icon).position(x: circle.x, y: circle.y)
                }
                // The dragged file and the pointer.
                RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(Color(hex: 0x32ADE6))
                    .frame(width: 13, height: 16).position(x: 179.5, y: 93)
                let pointer = SVGPath("M161 68v20l5.4-4.6 4 8.8 4-1.8-4-8.8h7z", viewBox: CGSize(width: 340, height: 164))
                pointer.fill(.white).frame(width: 340, height: 164)
                pointer.stroke(Color(hex: 0x15161B), style: StrokeStyle(lineWidth: 1.3, lineJoin: .round)).frame(width: 340, height: 164)
            }
            .frame(width: 340, height: 164)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.DropRing.heroDescription)
    }

    private func icon(_ data: String) -> some View {
        LineIcon(data, size: 16.4, lineWidth: 2, viewBox: 20, color: .white)
    }
}

// MARK: - Settings

struct DropRingSettingsView: View {
    enum Tab: Hashable { case circles, opening }

    let feature: DropRingFeature
    let settings: SettingsStore
    @State private var tab: Tab = .circles
    @State private var shortcuts: [String]?
    @State private var addingPerson = false
    @Environment(\.settingsHighlight) private var highlight

    private var items: [RingItem] { settings.value(DropRingFeature.itemsKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ASSegmented(feature.displayName, selection: $tab, options: [
                (Tab.circles, L10n.DropRing.circles),
                (Tab.opening, L10n.DropRing.tabOpeningLook),
            ], size: .wide)
            switch tab {
            case .circles: circles
            case .opening: opening
            }
        }
        .onChange(of: highlight, initial: true) { _, anchor in
            switch anchor {
            case DropRingFeature.Anchor.circles: tab = .circles
            case DropRingFeature.Anchor.shake, DropRingFeature.Anchor.size: tab = .opening
            default: break
            }
        }
        .sheet(isPresented: $addingPerson) {
            PersonSheet { feature.add($0) }
        }
    }

    // MARK: Circles

    private var circles: some View {
        ASSection {
            HStack(spacing: 8) {
                Text(L10n.DropRing.circlesHelp).font(AS.footnote).foregroundStyle(AS.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(L10n.DropRing.resetCircles) { feature.setItems(RingItem.starterRing()) }
                    .buttonStyle(ASButtonStyle(.secondary, height: 22, fontSize: 12))
                addMenu
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item, index: index)
            }
        }
        .settingsAnchor(DropRingFeature.Anchor.circles)
    }

    private func row(_ item: RingItem, index: Int) -> some View {
        let name = feature.title(of: item)
        return HStack(spacing: 10) {
            LineIcon("M3 5.5h10M3 8h10M3 10.5h10", size: 12, lineWidth: 1.6, color: Color(hex: 0x8E8E93))
            GlassTile(size: 26, radius: 7) { icon(item) }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name).font(AS.body).foregroundStyle(AS.text).lineLimit(1)
                if feature.isMissing(item) {
                    Text(L10n.DropRing.missingTag).font(AS.footnote).foregroundStyle(AS.orange).lineLimit(1)
                } else {
                    Text(feature.actionTitle(of: item)).font(AS.footnote).foregroundStyle(AS.textTertiary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if case let .folder(path, mode) = item.kind {
                ASSegmented(L10n.DropRing.copyOrMove(name), selection: Binding(
                    get: { mode },
                    set: { replace(index, with: RingItem(id: item.id, kind: .folder(path: path, mode: $0))) }
                ), options: [
                    (RingItem.FolderMode.copy, L10n.DropRing.copy),
                    (RingItem.FolderMode.move, L10n.DropRing.move),
                ], size: .small)
            }
            Button { remove(index) } label: {
                LineIcon("M3.5 8h9", size: 10, lineWidth: 2.4, color: AS.icon)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.white.opacity(0.12)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(L10n.DropRing.removeCircle(name))
            .accessibilityLabel(L10n.DropRing.removeCircle(name))
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .contentShape(Rectangle())
        .draggable(Self.dragPrefix + item.id.uuidString) {
            Text(name).font(AS.body).padding(.horizontal, 10).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(AS.panel))
        }
        .dropDestination(for: String.self) { dropped, _ in
            guard let text = dropped.first, text.hasPrefix(Self.dragPrefix),
                  let id = UUID(uuidString: String(text.dropFirst(Self.dragPrefix.count))) else { return false }
            return move(id, to: item.id)
        }
        .accessibilityAction(named: L10n.DropRing.moveUp) { move(index, by: -1) }
        .accessibilityAction(named: L10n.DropRing.moveDown) { move(index, by: 1) }
    }

    private static let dragPrefix = "allset.dropring.circle:" // l10n-ignore

    @ViewBuilder private func icon(_ item: RingItem) -> some View {
        switch item.kind {
        case .folder:
            LineIcon("M2.5 4h4l1.6 1.6h5.4v6.9h-11z", size: 15, color: AS.icon)
        case .cargo:
            LineIcon("M3 3.5h10v9H3zM3 6.8h10M6.5 9.2h3", size: 15, color: AS.icon)
        case .trash:
            LineIcon("M3.5 4.5h9M5 4.5l.8 8h4.4l.8-8M6.5 2.8h3", size: 15, color: AS.icon)
        case .shortcut:
            LineIcon("M8 2.5l5.5 3L8 8.5l-5.5-3zM2.5 9l5.5 3 5.5-3", size: 15, color: AS.icon)
        case let .contact(name, _, _):
            Text(RingItem.initials(name)).font(AS.font(10, .bold)).foregroundStyle(AS.icon)
        case let .app(path):
            if ShareServices.canShare(appName: feature.title(of: item)) || ShareServices.isChatApp(at: URL(fileURLWithPath: path)) {
                LineIcon("M2.8 3.5h10.4v7H7l-2.6 2.2v-2.2H2.8z", size: 15, color: AS.icon)
            } else if let image = feature.icon(of: item) {
                Image(nsImage: image).resizable().frame(width: 18, height: 18)
            } else {
                LineIcon(ASIcon.warning, size: 15, color: AS.orange)
            }
        }
    }

    private var addMenu: some View {
        Menu {
            Button(L10n.DropRing.addFolder) { pick(folders: true) }
            Button(L10n.DropRing.addApp) { pick(folders: false) }
            Button(L10n.DropRing.addPerson) { addingPerson = true }
            Menu(L10n.DropRing.addShortcut) {
                if let shortcuts {
                    if shortcuts.isEmpty { Text(L10n.DropRing.noShortcuts) }
                    ForEach(shortcuts, id: \.self) { name in
                        Button(name) { feature.add(RingItem(kind: .shortcut(name: name))) }
                    }
                } else {
                    Text(L10n.DropRing.loadingShortcuts)
                }
            }
            if !items.contains(where: { $0.kind == .cargo }) {
                Button(L10n.DropRing.cargo) { feature.add(RingItem(kind: .cargo)) }
            }
            if !items.contains(where: { $0.kind == .trash }) {
                Button(L10n.DropRing.trash) { feature.add(RingItem(kind: .trash)) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(L10n.DropRing.addCircle).lineLimit(1)
                LineIcon(ASIcon.popUpChevrons, size: 10, lineWidth: 1.6, viewBox: 10).frame(width: 10, height: 12)
            }
            .font(AS.font(12))
            .foregroundStyle(AS.text)
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).fill(AS.controlFill))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(L10n.DropRing.addCircle)
        .task { if shortcuts == nil { shortcuts = await ShortcutsRunner.list() } }
    }

    // MARK: Opening and look

    private var opening: some View {
        let shake = settings.value(DropRingFeature.shakeKey)
        return ASSection {
            ASToggleRow(L10n.DropRing.shake, isOn: Binding(
                get: { settings.value(DropRingFeature.shakeKey) },
                set: { settings.set($0, for: DropRingFeature.shakeKey); feature.updateShake() }
            ))
            .settingsAnchor(DropRingFeature.Anchor.shake)
            ASToggleRow(L10n.DropRing.shakeOnlyDragging, isOn: settings.binding(DropRingFeature.shakeDraggingKey))
                .disabled(!shake)
                .opacity(shake ? 1 : 0.4)
            ASRow(L10n.DropRing.sensitivity) {
                HStack(spacing: 10) {
                    Text(L10n.DropRing.bigShake).font(AS.footnote).foregroundStyle(AS.textTertiary)
                    ASSlider(L10n.DropRing.sensitivity, value: Binding(
                        get: { settings.value(DropRingFeature.sensitivityKey) },
                        set: { settings.set($0, for: DropRingFeature.sensitivityKey); feature.updateShake() }
                    ))
                    Text(L10n.DropRing.smallWiggle).font(AS.footnote).foregroundStyle(AS.textTertiary)
                }
                .allowsHitTesting(shake)
                .opacity(shake ? 1 : 0.4)
            }
            ASRow(L10n.DropRing.size) {
                ASSlider(L10n.DropRing.size, value: settings.binding(DropRingFeature.sizeKey), in: 52 ... 104, step: 4)
                    .overlay(alignment: .top) {
                        HStack(spacing: 0) {
                            ForEach(0 ..< 14, id: \.self) { index in
                                if index > 0 { Spacer(minLength: 0) }
                                Circle().fill(Color(hex: 0x636366)).frame(width: 2, height: 2)
                            }
                        }
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                    }
            }
            .settingsAnchor(DropRingFeature.Anchor.size)
            ASRow(L10n.DropRing.style) {
                ASSegmented(L10n.DropRing.style, selection: settings.binding(DropRingFeature.glassKey), options: [
                    (true, L10n.DropRing.glass),
                    (false, L10n.DropRing.solid),
                ])
            }
        }
    }

    // MARK: Editing

    private func replace(_ index: Int, with item: RingItem) {
        var list = items
        guard list.indices.contains(index) else { return }
        list[index] = item
        feature.setItems(list)
    }

    /// Puts the dragged circle where `target` is.
    private func move(_ id: UUID, to target: UUID) -> Bool {
        var list = items
        guard id != target, let from = list.firstIndex(where: { $0.id == id }), let to = list.firstIndex(where: { $0.id == target }) else { return false }
        let item = list.remove(at: from)
        list.insert(item, at: to)
        feature.setItems(list)
        return true
    }

    private func move(_ index: Int, by offset: Int) {
        var list = items
        let target = index + offset
        guard list.indices.contains(index), list.indices.contains(target) else { return }
        list.swapAt(index, target)
        feature.setItems(list)
    }

    private func remove(_ index: Int) {
        var list = items
        guard list.indices.contains(index) else { return }
        list.remove(at: index)
        feature.setItems(list)
    }

    private func pick(folders: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = folders
        panel.canChooseFiles = !folders
        panel.allowsMultipleSelection = true
        if !folders {
            panel.allowedContentTypes = [.application]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
        }
        guard panel.runModal() == .OK else { return }
        let added = panel.urls.map { url in
            RingItem(kind: folders ? .folder(path: url.path, mode: .copy) : .app(path: url.path))
        }
        feature.setItems(items + added)
    }
}

/// Name, phone or email, and Messages or Mail.
private struct PersonSheet: View {
    let onAdd: (RingItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var handle = ""
    @State private var channel = RingItem.Channel.messages

    var body: some View {
        VStack(alignment: .leading, spacing: OmniStyle.s3) {
            Text(L10n.DropRing.personTitle).font(.title3.weight(.semibold))
            TextField(L10n.DropRing.personName, text: $name)
            TextField(L10n.DropRing.personHandle, text: $handle)
            Picker(L10n.DropRing.sendWith, selection: $channel) {
                Text(L10n.DropRing.messages).tag(RingItem.Channel.messages)
                Text(L10n.DropRing.mail).tag(RingItem.Channel.mail)
            }
            .pickerStyle(.segmented)
            Text(L10n.DropRing.personHelp).font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(L10n.Common.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L10n.Common.add) {
                    onAdd(RingItem(kind: .contact(
                        name: name.trimmingCharacters(in: .whitespaces),
                        handle: handle.trimmingCharacters(in: .whitespaces), channel: channel
                    )))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || handle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(OmniStyle.s5)
        .frame(width: 380)
    }
}
