import AppKit
import Observation
import OmniCore
import OmniPlatform
import os
import SwiftUI

/// Drop Ring: a ring of circles (folders, apps, people, shortcuts, Cargo,
/// Trash) opens around the pointer with ⌃⌥⌘D or a shake. Drop files on a
/// circle to send them there, or click it to open it.
@MainActor
@Observable
public final class DropRingFeature: Feature {
    public static var showHotkey: HotkeyAction {
        HotkeyAction(
            id: "dropring.show", title: L10n.DropRing.hotkey,
            defaultCombo: KeyCombo(keyCode: 2, modifiers: [.control, .option, .command]) // ⌃⌥⌘D
        )
    }

    static let itemsKey = SettingKey.feature("dropring", "items", default: RingItem.starterRing())
    static let shakeKey = SettingKey.feature("dropring", "shake", default: true)
    static let shakeDraggingKey = SettingKey.feature("dropring", "shakeOnlyDragging", default: true)
    static let sensitivityKey = SettingKey.feature("dropring", "sensitivity", default: 0.5)
    static let sizeKey = SettingKey.feature("dropring", "size", default: 72.0)
    static let glassKey = SettingKey.feature("dropring", "glass", default: true)

    enum Anchor {
        static let circles = "dropring.circles"
        static let shake = "dropring.shake"
        static let size = "dropring.size"
    }

    public let id: FeatureID = "dropring"
    public var displayName: String { L10n.DropRing.displayName }
    public var summary: String { L10n.DropRing.summary }
    public let symbolName = "circle.dashed"
    public let group: FeatureGroup = .files
    public let requiredPermissions: Set<Permission> = []
    public var declaredHotkeys: [HotkeyAction] { [Self.showHotkey] }
    public var userContentSettingKeys: Set<String> { [Self.itemsKey.name] }

    /// Files collected on the Cargo shelf (references only; nothing is copied).
    private(set) var cargo: [URL] = []
    @ObservationIgnored private(set) var settings: SettingsStore?
    @ObservationIgnored private var controller: RingController?
    @ObservationIgnored private var shake: ShakeMonitor?
    @ObservationIgnored private var log: Logger?

    public init() {}

    public func enable(context: FeatureContext) throws {
        let settings = context.settings
        self.settings = settings
        log = context.log
        let controller = RingController()
        let model = controller.model
        model.title = { [weak self] in self?.title(of: $0) ?? "" }
        model.actionTitle = { [weak self] in self?.actionTitle(of: $0) ?? "" }
        model.icon = { [weak self] in self?.icon(of: $0) }
        model.onDrop = { [weak self] item, urls in
            controller.hide()
            self?.drop(urls, on: item)
        }
        model.onClick = { [weak self] item in
            controller.hide()
            self?.open(item)
        }
        model.onDismiss = { controller.hide() }
        self.controller = controller
        context.lifetime.add { controller.close() }
        context.registerHotkey(Self.showHotkey) { [weak self] in self?.toggleRing() }
        context.registerCommand(Command(
            id: "dropring.show", title: L10n.DropRing.hotkey, keywords: ["drop", "files", "ring", "move", "send"],
            symbolName: symbolName
        ) { [weak self] in self?.toggleRing() })
        updateShake()
        context.lifetime.add { [weak self] in
            self?.shake?.stop()
            self?.shake = nil
        }
    }

    public func disable() {
        controller = nil
        settings = nil
        cargo = []
    }

    public func makeSettingsView() -> AnyView {
        guard let settings else { return AnyView(EmptyView()) }
        return AnyView(DropRingSettingsView(feature: self, settings: settings))
    }

    // MARK: Showing

    var items: [RingItem] { settings?.value(Self.itemsKey) ?? [] }

    func toggleRing() {
        guard let controller, let settings else { return }
        if controller.isShown { controller.hide(); return }
        let model = controller.model
        model.items = settings.value(Self.itemsKey)
        model.glass = settings.value(Self.glassKey)
        model.cargoCount = cargo.count
        model.layout.orbSize = settings.value(Self.sizeKey)
        controller.show()
    }

    /// Starts or stops watching for a shake to match the settings.
    func updateShake() {
        guard let settings else { return }
        guard settings.value(Self.shakeKey) else {
            shake?.stop()
            shake = nil
            return
        }
        let monitor = shake ?? ShakeMonitor(
            sensitivity: settings.value(Self.sensitivityKey),
            onlyWhileDragging: { settings.value(Self.shakeDraggingKey) },
            onShake: { [weak self] in self?.toggleRing() }
        )
        monitor.sensitivity = settings.value(Self.sensitivityKey)
        monitor.start()
        shake = monitor
    }

    // MARK: Names and icons

    func title(of item: RingItem) -> String {
        switch item.kind {
        case let .folder(path, _), let .app(path):
            FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: "")
        case let .contact(name, _, _): name
        case let .shortcut(name): name
        case .cargo: L10n.DropRing.cargo
        case .trash: L10n.DropRing.trash
        }
    }

    func actionTitle(of item: RingItem) -> String {
        let name = title(of: item)
        return switch item.kind {
        case let .folder(_, mode): mode == .move ? L10n.DropRing.moveTo(name) : L10n.DropRing.copyTo(name)
        case let .app(path):
            if ShareServices.canShare(appName: name) {
                L10n.DropRing.shareWith(name)
            } else if ShareServices.isChatApp(at: URL(fileURLWithPath: path)) {
                L10n.DropRing.sendWith(name)
            } else {
                L10n.DropRing.openWith(name)
            }
        case let .contact(_, _, channel): L10n.DropRing.sendTo(name, channel == .mail ? L10n.DropRing.mail : L10n.DropRing.messages)
        case .shortcut: L10n.DropRing.run(name)
        case .cargo: L10n.DropRing.addToCargo
        case .trash: L10n.DropRing.moveToTrash
        }
    }

    func icon(of item: RingItem) -> NSImage? {
        switch item.kind {
        case let .folder(path, _), let .app(path):
            FileManager.default.fileExists(atPath: path) ? NSWorkspace.shared.icon(forFile: path) : nil
        case .shortcut:
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts").map { NSWorkspace.shared.icon(forFile: $0.path) }
        case .trash:
            NSImage(named: NSImage.trashEmptyName)
        case .contact, .cargo:
            nil
        }
    }

    func isMissing(_ item: RingItem) -> Bool {
        item.path.map { !FileManager.default.fileExists(atPath: $0) } ?? false
    }

    // MARK: Actions

    func drop(_ urls: [URL], on item: RingItem) {
        guard !urls.isEmpty else { return }
        if isMissing(item) {
            HUD.show(L10n.DropRing.missing(title(of: item)), symbol: "exclamationmark.triangle")
            return
        }
        let count = L10n.DropRing.items(urls.count)
        switch item.kind {
        case let .folder(path, mode):
            let folder = URL(fileURLWithPath: path, isDirectory: true)
            let name = title(of: item)
            let log = log
            Task.detached(priority: .userInitiated) {
                let result = FileTransfer.transfer(urls, to: folder, mode: mode)
                await MainActor.run {
                    log?.notice("Drop Ring: \(mode.rawValue, privacy: .public) \(result.done.count) done, \(result.skipped.count) skipped, \(result.failed.count) failed")
                    if !result.failed.isEmpty {
                        HUD.show(L10n.DropRing.failed(L10n.DropRing.items(result.failed.count)), symbol: "exclamationmark.triangle")
                    } else if result.done.isEmpty {
                        HUD.show(L10n.DropRing.alreadyThere, symbol: "folder")
                    } else {
                        let items = L10n.DropRing.items(result.done.count)
                        HUD.show(mode == .move ? L10n.DropRing.moved(items, name) : L10n.DropRing.copied(items, name), symbol: "folder")
                    }
                }
            }
        case let .app(path):
            // Messages, Slack, WhatsApp…: open its share window with the files attached.
            let app = URL(fileURLWithPath: path)
            if let service = ShareServices.service(forApp: title(of: item), items: urls) {
                ShareServices.share(urls, with: service)
            } else if !ShareServices.isChatApp(at: app) {
                NSWorkspace.shared.open(urls, withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            } else {
                // A chat app without a Share extension (Slack, WhatsApp):
                // copy the files and bring the app forward to paste them.
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects(urls as [NSURL])
                NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
                HUD.show(L10n.DropRing.pasteInto(title(of: item)), symbol: "doc.on.clipboard", duration: .seconds(2.5))
            }
        case let .contact(_, handle, channel):
            if let service = NSSharingService(named: channel == .mail ? .composeEmail : .composeMessage) {
                service.recipients = [handle]
                ShareServices.share(urls, with: service)
            }
        case let .shortcut(name):
            ShortcutsRunner.run(name, inputs: urls)
        case .cargo:
            for url in urls where !cargo.contains(url) { cargo.append(url) }
            HUD.show(L10n.DropRing.addedToCargo(count), symbol: "shippingbox")
        case .trash:
            var moved = 0
            for url in urls {
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    moved += 1
                } catch {
                    log?.error("Drop Ring: couldn't move an item to the Trash: \(error.localizedDescription, privacy: .public)")
                }
            }
            log?.notice("Drop Ring: moved \(moved) item(s) to the Trash")
            HUD.show(moved == urls.count ? L10n.DropRing.trashed(count) : L10n.DropRing.failed(L10n.DropRing.items(urls.count - moved)), symbol: "trash")
        }
    }

    /// A click: open the folder or app, start a message, run the shortcut,
    /// show the Cargo shelf, or open the Trash.
    func open(_ item: RingItem) {
        switch item.kind {
        case let .folder(path, _):
            NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
        case let .app(path):
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: NSWorkspace.OpenConfiguration())
        case let .contact(_, handle, channel):
            let encoded = handle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? handle
            if let url = URL(string: channel == .mail ? "mailto:\(encoded)" : "imessage:\(encoded)") { NSWorkspace.shared.open(url) }
        case let .shortcut(name):
            ShortcutsRunner.run(name, inputs: [])
        case .cargo:
            showCargo()
        case .trash:
            if let trash = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first { NSWorkspace.shared.open(trash) }
        }
    }

    // MARK: Cargo

    func showCargo() {
        controller?.showShelf(CargoShelfView(feature: self))
    }

    func hideCargo() {
        controller?.hideShelf()
    }

    func clearCargo() {
        cargo = []
        controller?.model.cargoCount = 0
    }

    // MARK: Editing circles

    func setItems(_ items: [RingItem]) {
        settings?.set(items, for: Self.itemsKey)
    }

    func add(_ item: RingItem) {
        setItems(items + [item])
    }
}
