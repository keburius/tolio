import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Fills the screen when a reminder is due: REMINDER, the title, Close and Snooze.
struct MinderAlertView: View {
    let title: String
    let snoozeChoices: [Int]
    let defaultSnooze: Int
    let onDone: () -> Void
    let onSnooze: (_ minutes: Int) -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.35))
            VStack(spacing: 18) {
                Text(L10n.DeskMinder.alertKicker.uppercased(with: .current))
                    .font(.system(size: 13, weight: .semibold)).tracking(3).opacity(0.7)
                Text(title)
                    .font(.system(size: 46, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 900)
                HStack(spacing: 14) {
                    Button(action: onDone) {
                        Label(L10n.DeskMinder.done, systemImage: "circle")
                            .padding(.horizontal, 26).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.22)))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    Menu {
                        ForEach(snoozeChoices, id: \.self) { minutes in
                            Button(L10n.DeskMinder.snoozeFor(StretchScale.label(minutes: minutes, minuteFormat: L10n.DeskMinder.minutes, hourFormat: L10n.DeskMinder.hours))) {
                                onSnooze(minutes)
                            }
                        }
                    } label: {
                        Label(L10n.DeskMinder.snooze, systemImage: "timer")
                            .padding(.horizontal, 20).padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.5)))
                    } primaryAction: {
                        onSnooze(defaultSnooze)
                    }
                    .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(40)
            .scaleEffect(shown || OmniStyle.reduceMotion ? 1 : 0.94)
            .opacity(shown ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear { withAnimation(OmniStyle.motion(.spring(response: 0.45, dampingFraction: 0.8))) { shown = true } }
        .onExitCommand(perform: onDone)
    }
}
