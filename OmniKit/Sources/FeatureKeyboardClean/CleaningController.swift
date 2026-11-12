import AppKit
import Observation
import OmniCore
import OmniPlatform
import SwiftUI

/// Runs a cleaning session: a filtering tap that swallows all keyboard
/// events, a full-screen overlay on every display with an Unlock button,
/// and a watchdog that unlocks at the time limit.
///
/// Fail-open guarantees:
/// - If macOS disables the tap, the session ends immediately (no re-enable).
/// - The watchdog always ends the session after at most 10 minutes.
/// - If Omni quits or crashes, the tap goes away with the process.
@MainActor
@Observable
final class CleaningController {
    private(set) var session: CleaningSession?
    private(set) var now = Date()
    @ObservationIgnored private var tap: EventTap?
    @ObservationIgnored private var panels: [NSPanel] = []
    @ObservationIgnored private var watchdog: Timer?
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored var onEnd: ((CleaningEndReason) -> Void)?
    @ObservationIgnored private let log = Log.logger("keyboardclean")

    var isActive: Bool { session != nil }

    func start(duration: TimeInterval) throws {
        guard session == nil else { return }
        let tap = EventTap(mask: CleaningSession.blockedEvents, mode: .filtering, handler: { _, _ in true }, onDisabled: {
            [weak self] in self?.end(.tapDisabled)
        })
        try tap.start()
        self.tap = tap
        let session = CleaningSession(start: Date(), duration: duration)
        self.session = session
        now = session.start

        let watchdog = Timer(fire: session.end, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.end(.timeLimit) }
        }
        RunLoop.main.add(watchdog, forMode: .common)
        self.watchdog = watchdog
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker

        showOverlays()
        log.info("Keyboard cleaning started (\(Int(session.duration)) s limit)")
    }

    func end(_ reason: CleaningEndReason) {
        guard session != nil else { return }
        // Keyboard first: stop swallowing before anything else can fail.
        tap?.stop()
        tap = nil
        watchdog?.invalidate()
        watchdog = nil
        ticker?.invalidate()
        ticker = nil
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        session = nil
        log.info("Keyboard cleaning ended: \(String(describing: reason), privacy: .public)")
        onEnd?(reason)
    }

    private func showOverlays() {
        for screen in NSScreen.screens {
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: CleaningOverlay(controller: self))
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }
}

private struct CleaningOverlay: View {
    let controller: CleaningController

    var body: some View {
        ZStack {
            Color.black.opacity(0.82)
            VStack(spacing: 18) {
                Image(systemName: "keyboard").font(.system(size: 64, weight: .light))
                Text("Keyboard locked for cleaning").font(.largeTitle.weight(.semibold))
                if let session = controller.session {
                    Text("Unlocks automatically in \(session.remainingText(at: controller.now))")
                        .font(.title3).monospacedDigit().foregroundStyle(.secondary)
                }
                Button {
                    controller.end(.unlockedByUser)
                } label: {
                    Text("Unlock Keyboard").font(.title2.weight(.semibold)).padding(.horizontal, 28).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Click with your mouse or trackpad to unlock.").font(.callout).foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
        }
        .ignoresSafeArea()
    }
}
