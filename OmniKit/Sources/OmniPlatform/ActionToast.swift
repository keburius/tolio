import AppKit
import OmniCore
import SwiftUI

/// A short notice with one button (e.g. "Copied a link · Open"). Unlike the
/// HUD it can be clicked; it never takes focus and hides by itself.
@MainActor
public enum ActionToast {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
    }

    private static var panel: Panel?
    private static var hideTask: Task<Void, Never>?

    public static func show(
        _ message: String, symbol: String, actionTitle: String,
        duration: Duration = .seconds(6), action: @escaping @MainActor () -> Void
    ) {
        let panel = panel ?? makePanel()
        self.panel = panel
        let host = NSHostingView(rootView: ToastView(message: message, symbol: symbol, actionTitle: actionTitle) {
            hide()
            action()
        })
        panel.contentView = host
        let size = host.fittingSize
        panel.setContentSize(size)
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + frame.height * 0.18))
        }
        panel.orderFrontRegardless()
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            hide()
        }
    }

    public static func hide() {
        hideTask?.cancel()
        panel?.orderOut(nil)
    }

    private static func makePanel() -> Panel {
        let panel = Panel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}

private struct ToastView: View {
    let message: String
    let symbol: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: OmniStyle.s3) {
            Label(message, systemImage: symbol).font(.title3.weight(.medium)).lineLimit(2)
            Button(actionTitle, action: action).controlSize(.large).buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .frame(maxWidth: 560)
        .omniPanelBackground(radius: OmniStyle.panelRadius)
    }
}
