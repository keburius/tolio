import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// Home: the song, your next events and the focus timer side by side.
/// Each card opens its full page.
struct HomePage: View {
    let model: IslandModel
    @Environment(\.islandActions) private var actions

    var body: some View {
        let options = model.options
        HStack(spacing: 10) {
            if options.showMusic {
                HomeMusic(player: model.nowPlaying).frame(width: 236)
            }
            if options.showCalendar {
                HomeCalendar(services: model.services, more: { go(.calendar) })
            }
            if options.showFocus {
                HomeFocus(workspace: model.services.workspace, more: { go(.focus) }).frame(width: 128)
            }
        }
    }

    private func go(_ page: IslandModel.Page) {
        guard model.pages.contains(page) else { return }
        model.show(page)
        actions.pageChanged()
    }
}

private struct HomeMusic: View {
    let player: NowPlaying

    var body: some View {
        let track = player.track
        IslandCard(padding: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Button(action: player.openPlayer) {
                        Cover(image: track == nil ? nil : player.artwork, playing: player.isPlaying, accent: player.accent, size: 46)
                            .overlay(alignment: .bottomTrailing) {
                                if track != nil { PlayerBadge(player: player.player, size: 16).offset(x: 4, y: 4) }
                            }
                    }
                    .buttonStyle(IslandPress())
                    .disabled(track == nil)
                    VStack(alignment: .leading, spacing: 1) {
                        if let track {
                            Marquee(text: track.title, font: .system(size: 14, weight: .semibold))
                            Text(track.artist.isEmpty ? track.album : track.artist)
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                        } else {
                            Text(L10n.Island.nothingPlaying).font(.system(size: 14, weight: .semibold))
                            Text(L10n.Island.nothingPlayingHint).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 6)
                HStack(spacing: 0) {
                    control("backward.fill", L10n.Island.previous, action: player.previous)
                    Spacer()
                    PlayButton(playing: player.isPlaying, size: 38, action: player.playPause)
                    Spacer()
                    control("forward.fill", L10n.Island.next, action: player.next)
                }
                .padding(.horizontal, 14)
                .disabled(track == nil)
                .opacity(track == nil ? 0.35 : 1)
            }
        }
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).frame(width: 36, height: 30).contentShape(Rectangle())
        }
        .buttonStyle(IslandPress())
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct HomeCalendar: View {
    let services: IslandServices
    let more: () -> Void

    var body: some View {
        IslandCard(padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: more) {
                    HStack(spacing: 5) {
                        Text(Date().formatted(.dateTime.weekday(.abbreviated)).uppercased(with: .current)).foregroundStyle(CalendarPage.accent)
                        Text(Date().formatted(.dateTime.day()))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).opacity(0.4)
                    }
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                switch services.calendarAccess {
                case .allowed:
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        let upcoming = services.calendarEvents.filter { $0.end > context.date }.prefix(2)
                        if upcoming.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle").foregroundStyle(.green)
                                Text(L10n.Island.noMoreToday)
                            }
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(Array(upcoming)) { item in
                                    EventCard(item: item, now: context.date, open: { services.openCalendarItem(item) })
                                }
                            }
                        }
                    }
                case .notAsked:
                    Button(L10n.Island.showCalendar, action: services.requestCalendar)
                        .buttonStyle(.bordered).controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .denied:
                    Text(L10n.Island.calendarDenied).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}

private struct HomeFocus: View {
    let workspace: IslandWorkspace
    let more: () -> Void

    var body: some View {
        IslandCard(padding: 10) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let session = workspace.session
                let rest = session?.kind == .rest
                let tint = rest ? FocusPage.restTint : FocusPage.focusTint
                VStack(spacing: 6) {
                    Button(action: more) {
                        HStack(spacing: 4) {
                            Text(rest ? L10n.Island.rest : L10n.Island.focus)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).opacity(0.4)
                        }
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Text(IslandTimer.clock(session?.timeLeft(at: context.date) ?? TimeInterval(workspace.minutes(for: .focus) * 60)))
                        .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(tint)
                        .contentTransition(.numericText(countsDown: true))
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Spacer(minLength: 0)
                    Button {
                        if let session { workspace.toggle(session.id) } else { workspace.startSession(.focus) }
                    } label: {
                        Image(systemName: session?.isRunning == true ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(tint)
                            .frame(maxWidth: .infinity).frame(height: 30)
                            .background(Capsule().fill(tint.opacity(0.22)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(IslandPress())
                    .accessibilityLabel(session == nil ? L10n.Island.startTimer : L10n.Island.playPause)
                }
            }
        }
    }
}
