import Foundation
@testable import OmniCore
import Testing

struct MenuBarConfigurationTests {
    @Test func defaults() {
        let config = MenuBarConfiguration.standard
        #expect(config.mode == .separate)
        #expect(config.entries.map(\.id) == QuickAccessID.allCases)
        #expect(config.entries.filter(\.isVisible).map(\.id) == [.keepAwake, .screenshot, .clipboard])
    }

    @Test func iconsDependOnFeaturesBeingOn() {
        let config = MenuBarConfiguration.standard
        #expect(config.iconsToShow(available: [.keepAwake, .clipboard, .recording]) == [.keepAwake, .clipboard])
        #expect(config.iconsToShow(available: Set(QuickAccessID.allCases)) == [.keepAwake, .screenshot, .clipboard])
    }

    @Test func singleModeShowsNoIconsButKeepsChoices() {
        var config = MenuBarConfiguration.standard
        config.setVisible(true, for: .recording)
        config.mode = .single
        #expect(config.iconsToShow(available: Set(QuickAccessID.allCases)).isEmpty)
        config.mode = .separate
        #expect(config.iconsToShow(available: Set(QuickAccessID.allCases)) == [.keepAwake, .screenshot, .clipboard, .recording])
    }

    @Test func moveByOffsetClamps() {
        var config = MenuBarConfiguration.standard
        config.move(.clipboard, by: -1)
        #expect(config.entries.prefix(3).map(\.id) == [.keepAwake, .clipboard, .screenshot])
        config.move(.clipboard, by: -10)
        #expect(config.entries.first?.id == .clipboard)
        config.move(.keepAwake, by: 99)
        #expect(config.entries.last?.id == .keepAwake)
    }

    @Test func moveWithOffsetsLikeSwiftUI() {
        var config = MenuBarConfiguration.standard
        // Drag the first item below the third.
        config.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        #expect(config.entries.prefix(3).map(\.id) == [.screenshot, .clipboard, .keepAwake])
        // Drag the last item to the top.
        config.move(fromOffsets: IndexSet(integer: 5), toOffset: 0)
        #expect(config.entries.first?.id == .windowLayouts)
        #expect(config.entries.count == 6)
    }

    @Test func codableRoundTripAndUnknownIDs() throws {
        var config = MenuBarConfiguration.standard
        config.mode = .single
        config.move(.lockKeyboard, by: -4)
        let data = try JSONEncoder().encode(config)
        let roundTrip = try JSONDecoder().decode(MenuBarConfiguration.self, from: data)
        #expect(roundTrip == config)
        // A stored list from another version: unknown and duplicate IDs dropped, missing ones added.
        let json = #"{"mode":"separate","entries":[{"id":"clipboard","isVisible":false},{"id":"teleport","isVisible":true},{"id":"clipboard","isVisible":true}]}"#
        let decoded = try JSONDecoder().decode(MenuBarConfiguration.self, from: Data(json.utf8))
        #expect(decoded.entries.first == .init(id: .clipboard, isVisible: false))
        #expect(decoded.entries.count == QuickAccessID.allCases.count)
        #expect(decoded.isVisible(.keepAwake))
        let garbage = try JSONDecoder().decode(MenuBarConfiguration.self, from: Data("{}".utf8))
        #expect(garbage == .standard)
    }

    @MainActor @Test func storedAndReadThroughSettingsStore() {
        let defaults = UserDefaults(suiteName: "omni.tests.menubar.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        #expect(store.value(MenuBarConfiguration.key) == .standard)
        var config = store.value(MenuBarConfiguration.key)
        config.setVisible(false, for: .clipboard)
        store.set(config, for: MenuBarConfiguration.key)
        #expect(!store.value(MenuBarConfiguration.key).isVisible(.clipboard))
    }
}

struct SettingsIndexTests {
    let index = SettingsIndex(items: [
        .init(page: .feature("screenshots"), pageTitle: "Screenshots & Recording", label: "Frame rate", keywords: ["fps", "video"], anchor: "fps"),
        .init(page: .feature("screenshots"), pageTitle: "Screenshots & Recording", label: "Show the pointer", keywords: ["cursor", "frame"], anchor: "cursor"),
        .init(page: .feature("systemstats"), pageTitle: "System Stats", label: "Refresh every", keywords: ["interval", "rate"], anchor: "interval"),
        .init(page: .feature("keepawake"), pageTitle: "Keep Awake", label: "Keep the display on", keywords: ["caffeine"], anchor: "display"),
        .init(page: .menuBar, pageTitle: "Menu Bar", label: "One icon only"),
        .init(page: .menuBar, pageTitle: "Menu Bar", label: "One icon only"), // duplicate
    ])

    @Test func ranksLabelMatchesFirst() {
        #expect(index.search("frame").map(\.label) == ["Frame rate", "Show the pointer"])
        #expect(index.search("rate").map(\.label) == ["Frame rate", "Refresh every"])
    }

    @Test func synonymsAndPages() {
        #expect(index.search("caffeine").map(\.label) == ["Keep the display on"])
        #expect(index.search("recording").map(\.label) == ["Frame rate", "Show the pointer"])
        #expect(index.search("FPS").first?.anchor == "fps")
    }

    @Test func emptyAndMissing() {
        #expect(index.search("   ").isEmpty)
        #expect(index.search("zzz").isEmpty)
        #expect(index.items.count == 5)
    }
}

struct SettingsResetTests {
    @Test func resetsOnlyThatFeatureAndKeepsUserContent() {
        let stored = [
            "feature.clipboard.retentionDays", "feature.clipboard.excludedApps", "feature.clipboard.maxItems",
            "feature.clipboarder.x", "feature.snippets.items", "features.wanted", "hotkeys.bindings",
        ]
        let keys = SettingsReset.keysToRemove(feature: "clipboard", storedKeys: stored, keep: ["feature.clipboard.excludedApps"])
        #expect(keys == ["feature.clipboard.maxItems", "feature.clipboard.retentionDays"])
    }
}

struct ShortcutTableTests {
    let a = HotkeyAction(id: "a", title: "Keep awake", defaultCombo: KeyCombo(keyCode: 0, modifiers: [.control, .option, .command]))
    let b = HotkeyAction(id: "b", title: "Lock keyboard", defaultCombo: KeyCombo(keyCode: 37, modifiers: [.control, .option, .command]))
    let c = HotkeyAction(id: "c", title: "Scrolling", defaultCombo: nil)

    func table(_ bindings: HotkeyBindings = .init(), refused: Set<String> = [], bOn: Bool = false) -> ShortcutTable {
        ShortcutTable(sources: [
            .init(action: a, featureID: "keepawake", featureName: "Keep Awake", featureIsOn: true),
            .init(action: b, featureID: "keyboardclean", featureName: "Lock Keyboard", featureIsOn: bOn),
            .init(action: c, featureID: "screenshots", featureName: "Screenshots", featureIsOn: true),
        ], bindings: bindings, refused: refused)
    }

    @Test func defaultsHaveNoConflicts() {
        let t = table()
        #expect(t.rows.map(\.status) == [.ok, .ok, .unassigned])
        #expect(t.conflictCount == 0)
        #expect(t.rows.allSatisfy { $0.isDefault })
    }

    @Test func conflictWithAFeatureThatIsOff() {
        var bindings = HotkeyBindings()
        bindings.set(a.defaultCombo, for: "b")
        let t = table(bindings)
        #expect(t.rows[0].status == .conflict(otherTitle: "Lock keyboard", otherIsOn: false))
        #expect(t.rows[1].status == .conflict(otherTitle: "Keep awake", otherIsOn: true))
        #expect(!t.rows[1].isDefault)
        #expect(t.conflictCount == 2)
        #expect(t.owner(of: a.defaultCombo!, excluding: "c")?.id == "a")
    }

    @Test func refusedByMacOS() {
        #expect(table(refused: ["b"]).rows[1].status == .usedByAnotherApp)
    }

    @Test func clearedShortcutIsUnassigned() {
        var bindings = HotkeyBindings()
        bindings.set(nil, for: "a")
        #expect(table(bindings).rows[0].status == .unassigned)
    }
}

struct OnboardingModelTests {
    let options: [OnboardingModel.Option] = [
        .init(id: "palette", required: [], optional: []),
        .init(id: "clipboard", required: [], optional: [.accessibility]),
        .init(id: "windows", required: [.accessibility], optional: []),
        .init(id: "keepawake", required: [], optional: []),
        .init(id: "screenshots", required: [.screenRecording], optional: [.microphone, .accessibility]),
        .init(id: "snippets", required: [.accessibility], optional: []),
    ]

    @Test func recommendedByDefault() {
        let model = OnboardingModel(options: options)
        #expect(model.chosen == ["palette", "clipboard", "windows", "keepawake", "screenshots"])
        #expect(model.requiredPermissions == [.accessibility, .screenRecording])
        #expect(model.optionalPermissions == [.microphone])
    }

    @Test func presets() {
        var model = OnboardingModel(options: options)
        model.chooseNone()
        #expect(model.chosen.isEmpty && model.requiredPermissions.isEmpty)
        model.chooseEverything()
        #expect(model.chosen.count == 6)
        model.chooseRecommended()
        #expect(!model.chosen.contains("snippets"))
    }

    @Test func permissionsFollowChoice() {
        var model = OnboardingModel(options: options, chosen: ["clipboard"])
        #expect(model.requiredPermissions.isEmpty)
        #expect(model.optionalPermissions == [.accessibility])
        model.set(true, "windows")
        #expect(model.requiredPermissions == [.accessibility])
        #expect(model.optionalPermissions.isEmpty)
        #expect(model.users(of: .accessibility) == ["clipboard", "windows"])
    }

    @Test func changesOnlyWhatDiffers() {
        let model = OnboardingModel(options: options, chosen: ["palette", "windows"])
        let changes = model.changes(from: ["palette", "snippets"])
        #expect(changes.map(\.0) == ["windows", "snippets"])
        #expect(changes.map(\.1) == [true, false])
    }
}

struct ControlPanelFocusTests {
    let rows: [[ControlPanelFocus.Target]] = [
        [.tile(.screenshot), .tile(.recording), .tile(.clipboard)],
        [.recent(0), .recent(1)],
        [],
        [.layout("leftHalf"), .layout("rightHalf"), .layout("maximize")],
        [.settings, .quit],
    ]

    @Test func readingOrderAndWrap() {
        var focus = ControlPanelFocus(rows: rows)
        focus.move(.right)
        #expect(focus.current == .tile(.screenshot))
        focus.move(.left)
        #expect(focus.current == .quit)
        focus.move(.right)
        #expect(focus.current == .tile(.screenshot))
        #expect(focus.targets.count == 10)
    }

    @Test func upAndDownKeepColumn() {
        var focus = ControlPanelFocus(rows: rows)
        focus.focus(.tile(.clipboard))
        focus.move(.down)
        #expect(focus.current == .recent(1)) // clamped to the shorter row
        focus.move(.down)
        #expect(focus.current == .layout("rightHalf"))
        focus.move(.down)
        focus.move(.down)
        #expect(focus.current == .tile(.recording)) // wrapped to the top
        focus.move(.up)
        #expect(focus.current == .quit)
    }

    @Test func emptyPanel() {
        var focus = ControlPanelFocus(rows: [])
        focus.move(.down)
        #expect(focus.current == nil)
    }
}
