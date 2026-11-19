import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

extension IslandWidget {
    var title: String {
        switch self {
        case .timer: L10n.Island.timer
        case .todos: L10n.Island.todos
        case .notes: L10n.Island.notes
        case .quickActions: L10n.Island.quickActions
        case .shortcuts: L10n.Island.shortcuts
        case .stats: L10n.Island.stats
        }
    }

    var symbol: String {
        switch self {
        case .timer: "timer"
        case .todos: "checklist"
        case .notes: "note.text"
        case .quickActions: "switch.2"
        case .shortcuts: "square.stack.3d.up.fill"
        case .stats: "gauge.with.dots.needle.50percent"
        }
    }
}

/// Widgets in a 4-column row; more than fit go on further pages (pager below).
struct WidgetsPage: View {
    let model: IslandModel
    @State private var pageIndex = 0
    @State private var forward = true

    private var workspace: IslandWorkspace { model.services.workspace }

    var body: some View {
        let pages = IslandWidget.pages(workspace.layout)
        let index = min(pageIndex, max(pages.count - 1, 0))
        VStack(spacing: 6) {
            if pages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2").font(.system(size: 22))
                    Text(L10n.Island.noWidgets).font(.system(size: 12, weight: .semibold))
                    Menu(L10n.Island.addWidget) { WidgetMenuItems(workspace: workspace) }
                        .menuStyle(.button).controlSize(.small).fixedSize()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    let unit = (geo.size.width - 3 * 10) / 4
                    HStack(spacing: 10) {
                        ForEach(pages[index], id: \.self) { widget in
                            card(widget)
                                .frame(width: unit * CGFloat(widget.columns) + 10 * CGFloat(widget.columns - 1))
                                .contextMenu { menu(for: widget) }
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                        Spacer(minLength: 0)
                    }
                    .id(index)
                    .transition(.push(from: forward ? .trailing : .leading).combined(with: .opacity))
                }
                if pages.count > 1 {
                    WidgetPager(count: pages.count, index: index) { next in
                        // Direction first, page a moment later, so both slide the same way.
                        forward = next > index
                        DispatchQueue.main.async { pageIndex = next }
                    }
                }
            }
        }
        .animation(OmniStyle.motion(.spring(response: 0.35, dampingFraction: 0.8)), value: workspace.layout)
        .animation(OmniStyle.motion(.spring(response: 0.35, dampingFraction: 0.8)), value: index)
    }

    @ViewBuilder private func card(_ widget: IslandWidget) -> some View {
        switch widget {
        case .timer: TimerWidget(workspace: workspace)
        case .todos: TodosWidget(workspace: workspace)
        case .notes: NoteWidget(workspace: workspace)
        case .quickActions: QuickActionsWidget(services: model.services)
        case .shortcuts: ShortcutsWidget(workspace: workspace, library: model.services.shortcuts)
        case .stats: StatsWidget(load: model.services.load)
        }
    }

    @ViewBuilder private func menu(for widget: IslandWidget) -> some View {
        Button(L10n.Island.moveLeft) { workspace.move(widget, by: -1) }
            .disabled(workspace.layout.first == widget)
        Button(L10n.Island.moveRight) { workspace.move(widget, by: 1) }
            .disabled(workspace.layout.last == widget)
        Divider()
        Button(L10n.Island.removeWidget) { workspace.toggleWidget(widget) }
        Divider()
        Menu(L10n.Island.editWidgets) { WidgetMenuItems(workspace: workspace) }
    }
}

// MARK: - Timer

/// Set minutes with a scroll wheel (a tick of haptics per step) and start;
/// or start a Pomodoro. Running timers show as rings.
private struct TimerWidget: View {
    let workspace: IslandWorkspace

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(text: L10n.Island.timer, symbol: "timer")
                if workspace.timers.isEmpty {
                    MinuteWheel(minutes: Binding(get: { workspace.nextMinutes }, set: { workspace.nextMinutes = $0 }))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    HStack(spacing: 6) {
                        pill(L10n.Island.start, symbol: "play.fill") { workspace.addTimer(minutes: workspace.nextMinutes) }
                        pill(L10n.Island.pomodoro, symbol: "brain.head.profile") { workspace.startPomodoro() }
                            .help(L10n.Island.pomodoroHelp(workspace.focusMinutes, workspace.restMinutes))
                    }
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(spacing: 6) {
                            ForEach(workspace.timers.prefix(2)) { timer in row(timer, now: context.date) }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    HStack(spacing: 6) {
                        pill("+\(workspace.nextMinutes)", symbol: "plus") { workspace.addTimer(minutes: workspace.nextMinutes) }
                            .help(L10n.Island.addTimer)
                        if workspace.timers.count > 2 {
                            Text(L10n.Island.more(workspace.timers.count - 2)).font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func row(_ timer: IslandTimer, now: Date) -> some View {
        let tint: Color = timer.kind == .rest ? .green : .orange
        return HStack(spacing: 7) {
            Ring(value: timer.progress(at: now), tint: tint, width: 3).frame(width: 22, height: 22)
                .overlay(Image(systemName: timer.kind == .focus ? "brain.head.profile" : (timer.kind == .rest ? "cup.and.saucer.fill" : "timer"))
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(tint))
            VStack(alignment: .leading, spacing: 0) {
                Text(IslandTimer.clock(timer.timeLeft(at: now))).font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                if timer.kind != .plain {
                    Text(timer.kind == .focus ? L10n.Island.focus : L10n.Island.rest).font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
            Button { workspace.toggle(timer.id) } label: {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill").font(.system(size: 10, weight: .bold)).frame(width: 18, height: 18)
            }
            .buttonStyle(IslandPress()).accessibilityLabel(L10n.Island.playPause)
            Button { workspace.removeTimer(timer.id) } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).frame(width: 16, height: 18)
            }
            .buttonStyle(IslandPress()).opacity(0.6).accessibilityLabel(L10n.Island.stopTimer)
        }
    }

    private func pill(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 8.5, weight: .bold))
                Text(title).font(.system(size: 10, weight: .semibold)).lineLimit(1)
            }
            .padding(.horizontal, 7).frame(height: 20).frame(maxWidth: .infinity)
            .background(Capsule().fill(.white.opacity(0.14)))
        }
        .buttonStyle(IslandPress())
    }
}

/// Minutes that change as you scroll over them, with a haptic tick each step.
private struct MinuteWheel: View {
    @Binding var minutes: Int
    @State private var accumulated: CGFloat = 0

    static let steps = [1, 2, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90, 120]

    var body: some View {
        let index = Self.steps.firstIndex(of: minutes) ?? 3
        VStack(spacing: 0) {
            Text(index > 0 ? "\(Self.steps[index - 1])" : " ").font(.system(size: 10, weight: .medium).monospacedDigit()).opacity(0.3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(minutes)").font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: Double(minutes)))
                Text(L10n.Island.min).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
            }
            Text(index < Self.steps.count - 1 ? "\(Self.steps[index + 1])" : " ").font(.system(size: 10, weight: .medium).monospacedDigit()).opacity(0.3)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .background(ScrollCatcher { _, dy in step(dy) })
        .animation(OmniStyle.motion(.spring(response: 0.25, dampingFraction: 0.8)), value: minutes)
        .help(L10n.Island.scrollToSet)
        .accessibilityElement()
        .accessibilityLabel(L10n.Island.minutes(minutes))
        .accessibilityAdjustableAction { direction in
            step(direction == .increment ? -20 : 20)
        }
    }

    private func step(_ delta: CGFloat) {
        accumulated += delta
        guard abs(accumulated) >= 12 else { return }
        let index = Self.steps.firstIndex(of: minutes) ?? 3
        let next = min(max(index + (accumulated < 0 ? 1 : -1), 0), Self.steps.count - 1)
        accumulated = 0
        guard next != index else { return }
        minutes = Self.steps[next]
        AppFeel.tick()
    }
}

/// Reports scrolling over a view, sideways and up/down (and swallows it, so
/// the island doesn't read it as a swipe).
struct ScrollCatcher: NSViewRepresentable {
    let onScroll: (CGFloat, CGFloat) -> Void

    func makeNSView(context: Context) -> CatcherView { CatcherView() }
    func updateNSView(_ view: CatcherView, context: Context) { view.onScroll = onScroll }

    final class CatcherView: NSView {
        var onScroll: (CGFloat, CGFloat) -> Void = { _, _ in }
        override func scrollWheel(with event: NSEvent) {
            let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 12
            onScroll(event.scrollingDeltaX * scale, event.scrollingDeltaY * scale)
        }
    }
}

// MARK: - To-dos

private struct TodosWidget: View {
    let workspace: IslandWorkspace
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        let done = workspace.todos.filter(\.done).count
        IslandCard {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(text: L10n.Island.todos, symbol: "checklist",
                          trailing: workspace.todos.isEmpty ? nil : L10n.Island.doneOf(done, workspace.todos.count))
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                    TextField(L10n.Island.addTodo, text: $draft)
                        .textFieldStyle(.plain).font(.system(size: 11.5))
                        .focused($focused)
                        .onSubmit {
                            workspace.addTodo(draft)
                            draft = ""
                            focused = true
                        }
                }
                .padding(.horizontal, 7).frame(height: 22)
                .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.08)))
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(IslandTodo.sorted(workspace.todos)) { todo in
                            HStack(spacing: 6) {
                                Button { workspace.toggleTodo(todo.id) } label: {
                                    Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12)).foregroundStyle(todo.done ? .green : .white.opacity(0.6))
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                .buttonStyle(IslandPress())
                                .accessibilityLabel(todo.title)
                                Text(todo.title).font(.system(size: 11.5)).lineLimit(1)
                                    .strikethrough(todo.done).opacity(todo.done ? 0.45 : 1)
                                Spacer(minLength: 0)
                            }
                            .contextMenu {
                                Button(L10n.Island.delete) { workspace.removeTodo(todo.id) }
                                if done > 0 { Button(L10n.Island.clearDone) { workspace.clearDone() } }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(OmniStyle.motion(.spring(response: 0.3, dampingFraction: 0.8)), value: workspace.todos)
                }
            }
        }
    }
}

// MARK: - Note

private struct NoteWidget: View {
    let workspace: IslandWorkspace

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: 4) {
                CardTitle(text: L10n.Island.notes, symbol: "note.text",
                          trailing: workspace.note.isEmpty ? nil : L10n.Island.characters(workspace.note.count))
                ZStack(alignment: .topLeading) {
                    if workspace.note.isEmpty {
                        Text(L10n.Island.notePlaceholder).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.35))
                            .padding(.top, 1).padding(.leading, 5).allowsHitTesting(false)
                    }
                    TextEditor(text: Binding(get: { workspace.note }, set: { workspace.note = $0 }))
                        .font(.system(size: 11.5))
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.never)
                }
            }
        }
    }
}

// MARK: - Quick actions

/// Round switches: Wi-Fi, appearance, and Tolio's own actions (screenshot,
/// recording, Keep Awake, sticky note), plus display sleep.
private struct QuickActionsWidget: View {
    let services: IslandServices
    @State private var wifi = QuickControls.wifiOn
    @State private var dark = QuickControls.darkMode

    var body: some View {
        IslandCard(padding: 8) {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(text: L10n.Island.quickActions, symbol: "switch.2")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    if QuickControls.wifiInterface != nil {
                        tile(wifi ? "wifi" : "wifi.slash", L10n.Island.wifi, on: wifi) {
                            QuickControls.setWiFi(!wifi)
                            wifi = QuickControls.wifiOn
                        }
                    }
                    tile(dark ? "moon.fill" : "sun.max.fill", L10n.Island.darkMode, on: dark) {
                        QuickControls.toggleDarkMode()
                        dark.toggle()
                    }
                    command("keepawake.toggle", symbol: "cup.and.heat.waves.fill", L10n.Island.keepAwake)
                    command("screenshots.area", symbol: "camera.viewfinder", L10n.Island.screenshot)
                    command("stickynotes.new", symbol: "note.text.badge.plus", L10n.Island.newNote)
                    tile("display", L10n.Island.sleepDisplay, on: false) {
                        services.closeAll()
                        QuickControls.sleepDisplay()
                    }
                }
            }
        }
    }

    @ViewBuilder private func command(_ id: String, symbol: String, _ label: String) -> some View {
        if let command = services.command(id) {
            tile(symbol, label, on: false) {
                services.closeAll()
                // Let the island close before a screenshot starts.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    command.action()
                }
            }
        }
    }

    private func tile(_ symbol: String, _ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(on ? Color(red: 0.25, green: 0.55, blue: 1) : .white.opacity(0.14)))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(IslandPress())
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Shortcuts

private struct ShortcutsWidget: View {
    let workspace: IslandWorkspace
    let library: ShortcutsLibrary

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    CardTitle(text: L10n.Island.shortcuts, symbol: "square.stack.3d.up.fill")
                    Menu {
                        if !library.loaded {
                            Text(L10n.Island.loading)
                        } else if library.names.isEmpty {
                            Text(L10n.Island.noShortcuts)
                        }
                        ForEach(library.names, id: \.self) { name in
                            Toggle(name, isOn: Binding(get: { workspace.favoriteShortcuts.contains(name) }, set: { on in
                                if on { workspace.favoriteShortcuts.append(name) } else { workspace.favoriteShortcuts.removeAll { $0 == name } }
                            }))
                        }
                    } label: {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold)).frame(width: 18, height: 16)
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                    .help(L10n.Island.chooseShortcuts).accessibilityLabel(L10n.Island.chooseShortcuts)
                }
                if workspace.favoriteShortcuts.isEmpty {
                    Text(L10n.Island.shortcutsHint).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(workspace.favoriteShortcuts.prefix(6), id: \.self) { name in
                            Button { library.run(name) } label: {
                                HStack(spacing: 5) {
                                    if library.running == name {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Image(systemName: "play.circle.fill").font(.system(size: 11))
                                    }
                                    Text(name).font(.system(size: 10.5, weight: .medium)).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 7).frame(height: 24)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1)))
                            }
                            .buttonStyle(IslandPress())
                            .contextMenu {
                                Button(L10n.Island.removeShortcut) { workspace.favoriteShortcuts.removeAll { $0 == name } }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Stats

private struct StatsWidget: View {
    let load: SystemLoad

    var body: some View {
        IslandCard {
            VStack(alignment: .leading, spacing: 6) {
                CardTitle(text: L10n.Island.stats, symbol: "gauge.with.dots.needle.50percent")
                meter(L10n.Island.cpu, load.cpu, tint: .orange)
                Sparkline(values: load.history).stroke(.orange.opacity(0.8), lineWidth: 1.2).frame(height: 18)
                meter(L10n.Island.memory, load.memory, tint: Color(red: 0.4, green: 0.7, blue: 1))
                Spacer(minLength: 0)
            }
        }
    }

    private func meter(_ label: String, _ value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("\(Int((value * 100).rounded()))%").font(.system(size: 11, weight: .semibold).monospacedDigit()) // l10n-ignore
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(tint).frame(width: geo.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 4)
        }
        .animation(OmniStyle.motion(.easeOut(duration: 0.4)), value: value)
    }
}

private struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let step = rect.width / CGFloat(values.count - 1)
        for (i, value) in values.enumerated() {
            let point = CGPoint(x: CGFloat(i) * step, y: rect.maxY - rect.height * CGFloat(min(max(value, 0), 1)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// Arrows either side of a row of pills; the current page's pill is long.
private struct WidgetPager: View {
    let count: Int
    let index: Int
    let select: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            arrow("chevron.left", L10n.Island.previousWidgets, enabled: index > 0) { select(index - 1) }
            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    Button { select(i) } label: {
                        Capsule().fill(.white.opacity(i == index ? 0.9 : 0.28))
                            .frame(width: i == index ? 26 : 8, height: 8)
                            .padding(.vertical, 6).contentShape(Rectangle())
                    }
                    .buttonStyle(IslandPress())
                    .accessibilityLabel(L10n.Island.widgetPage(i + 1))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(.white.opacity(0.08)))
            arrow("chevron.right", L10n.Island.nextWidgets, enabled: index < count - 1) { select(index + 1) }
        }
        .animation(OmniStyle.motion(.spring(response: 0.32, dampingFraction: 0.75)), value: index)
    }

    private func arrow(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                .frame(width: 30, height: 26)
                .background(Capsule().fill(.white.opacity(0.1)))
                .contentShape(Capsule())
        }
        .buttonStyle(IslandPress())
        .disabled(!enabled)
        .opacity(enabled ? 0.9 : 0.3)
        .help(label)
        .accessibilityLabel(label)
    }
}
