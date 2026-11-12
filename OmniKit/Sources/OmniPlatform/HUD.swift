import AppKit
import SwiftUI

/// Shows a short, non-interactive message near the bottom of the main screen.
@MainActor
public enum HUD {
    private static var panel: NSPanel?
    private static var hideTask: Task<Void, Never>?

    public static func show(_ message: String, symbol: String = "checkmark.circle", duration: Duration = .seconds(1.2)) {
        let panel = panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: HUDView(message: message, symbol: symbol))
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - host.fittingSize.width / 2, y: frame.minY + frame.height * 0.18))
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            NSAnimationContext.runAnimationGroup { $0.duration = 0.25; panel.animator().alphaValue = 0 } completionHandler: {
                MainActor.assumeIsolated { panel.orderOut(nil) }
            }
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}

private struct HUDView: View {
    let message: String
    let symbol: String

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.title3.weight(.medium))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
