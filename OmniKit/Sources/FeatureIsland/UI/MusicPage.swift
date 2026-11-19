import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

/// The song: cover with the player's badge, title and artist, the bars,
/// then one row of controls.
struct MusicPage: View {
    let player: NowPlaying

    var body: some View {
        let track = player.track
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Button(action: player.openPlayer) {
                    Cover(image: track == nil ? nil : player.artwork, playing: player.isPlaying, accent: player.accent)
                        .overlay(alignment: .bottomTrailing) {
                            if track != nil { PlayerBadge(player: player.player, size: 24).offset(x: 7, y: 7) }
                        }
                }
                .buttonStyle(IslandPress())
                .help(L10n.Island.openApp(player.player?.appName ?? ""))
                .disabled(track == nil)

                VStack(alignment: .leading, spacing: 3) {
                    if let track {
                        Marquee(text: track.title, font: .system(size: 17, weight: .semibold))
                        Text(track.artist.isEmpty ? track.album : track.artist)
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    } else {
                        Text(L10n.Island.nothingPlaying).font(.system(size: 17, weight: .semibold))
                        Text(L10n.Island.nothingPlayingHint).font(.system(size: 13)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    }
                }
                // A new song slides in.
                .id((track?.title ?? "") + (track?.artist ?? ""))
                .transition(.push(from: .bottom).combined(with: .opacity))
                .frame(maxWidth: .infinity, alignment: .leading)

                Equalizer(playing: player.isPlaying, tint: .white, bars: 5, height: 20).opacity(track == nil ? 0 : 0.9)
            }
            .animation(OmniStyle.motion(.spring(response: 0.45, dampingFraction: 0.75)), value: track?.title)

            Spacer(minLength: 10)

            HStack(spacing: 0) {
                control("list.bullet", L10n.Island.openApp(player.player?.appName ?? ""), size: 17, dim: true, action: player.openPlayer)
                Spacer()
                control("shuffle", L10n.Island.shuffle, size: 17, dim: !player.shuffle, action: player.toggleShuffle)
                Spacer()
                control("backward.fill", L10n.Island.previous, size: 22, action: player.previous)
                Spacer()
                PlayButton(playing: player.isPlaying, action: player.playPause)
                Spacer()
                control("forward.fill", L10n.Island.next, size: 22, action: player.next)
                Spacer()
                ZStack {
                    Image(systemName: "laptopcomputer").font(.system(size: 18, weight: .regular)).opacity(0.85)
                    // macOS's output picker, its own icon hidden, over ours.
                    RoutePicker(color: .clear).frame(width: 40, height: 34)
                }
                .frame(width: 40, height: 34)
                .help(L10n.Island.output)
                .accessibilityLabel(L10n.Island.output)
            }
            .disabled(track == nil)
            .opacity(track == nil ? 0.35 : 1)
        }
        .padding(.horizontal, 4)
    }

    private func control(_ symbol: String, _ label: String, size: CGFloat, dim: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold))
                .frame(width: 40, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(IslandPress())
        .opacity(dim ? 0.4 : 0.95)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Play/pause in a soft round button.
struct PlayButton: View {
    let playing: Bool
    var size: CGFloat = 50
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: playing ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .contentTransition(.symbolEffect(.replace.downUp))
                .frame(width: size, height: size)
                .background(Circle().fill(.white.opacity(hover ? 0.16 : 0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(IslandPress())
        .onHover { hover = $0 }
        .help(L10n.Island.playPause)
        .accessibilityLabel(L10n.Island.playPause)
    }
}

/// The cover: breathes gently while playing, a bit smaller when paused,
/// with a soft glow in its own color.
struct Cover: View {
    let image: NSImage?
    let playing: Bool
    let accent: Color
    var size: CGFloat = 66

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !playing || OmniStyle.reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Artwork(image: image, size: size, radius: size * 0.21)
                .scaleEffect(playing ? 1 + 0.015 * sin(t * 2.2) : 0.94)
                .shadow(color: accent.opacity(playing ? 0.4 : 0), radius: 14)
                .shadow(color: .black.opacity(0.5), radius: playing ? 7 : 2, y: 3)
        }
        .animation(OmniStyle.motion(.spring(response: 0.4, dampingFraction: 0.6)), value: playing)
    }
}

/// One line that scrolls slowly when it doesn't fit.
struct Marquee: View {
    let text: String
    let font: Font
    @State private var textWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let overflow = textWidth - geo.size.width
            TimelineView(.animation(minimumInterval: 1 / 30, paused: overflow <= 0 || OmniStyle.reduceMotion)) { context in
                let cycle = Double(overflow) / 22 + 4
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle * 2)
                // Pause 2 s at each end, scroll between.
                let phase = t < cycle ? min(max((t - 2) / (cycle - 4), 0), 1) : 1 - min(max((t - cycle - 2) / (cycle - 4), 0), 1)
                Text(text).font(font).lineLimit(1).fixedSize()
                    .background(GeometryReader { Color.clear.preference(key: WidthKey.self, value: $0.size.width) })
                    .offset(x: overflow > 0 ? -overflow * phase : 0)
            }
        }
        .frame(height: 22)
        .clipped()
        .onPreferenceChange(WidthKey.self) { textWidth = $0 }
        .accessibilityLabel(text)
    }

    private struct WidthKey: PreferenceKey {
        static let defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }
}

// MARK: - Mirror

/// The camera, mirrored, to check how you look before a call, with a
/// shutter to take a photo (saved to Pictures › All Set and copied).
struct MirrorPage: View {
    let camera: CameraMirror
    @State private var flash = false
    @State private var busy = false
    @State private var lastPhoto: URL?
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.07))
            switch camera.access {
            case .allowed:
                CameraPreview(session: camera.session.session)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            case .notAsked:
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill").font(.system(size: 20))
                    Button(L10n.Island.allowCamera) {
                        Task { await camera.requestAccess(); camera.start() }
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
            case .denied:
                Text(L10n.Island.cameraDenied).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center).padding()
            case .noCamera:
                Text(L10n.Island.noCamera).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.6))
            }
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .opacity(flash ? 0.85 : 0)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            if camera.running {
                Circle().fill(.green).frame(width: 6, height: 6).padding(10)
            }
        }
        .overlay(alignment: .bottom) {
            if camera.running { shutter.padding(.bottom, 10) }
        }
        .overlay(alignment: .bottomTrailing) {
            if let thumbnail, let lastPhoto {
                Button { NSWorkspace.shared.activateFileViewerSelecting([lastPhoto]) } label: {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                .help(L10n.Island.showInFinder)
                .accessibilityLabel(L10n.Island.showInFinder)
                .padding(10)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .frame(width: 300)
        .frame(maxWidth: .infinity)
    }

    /// A round white shutter, like the Camera app's.
    private var shutter: some View {
        Button(action: take) {
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 2.5).frame(width: 38, height: 38)
                Circle().fill(.white).frame(width: 30, height: 30).scaleEffect(busy ? 0.82 : 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .help(L10n.Island.takePhoto)
        .accessibilityLabel(L10n.Island.takePhoto)
    }

    private func take() {
        busy = true
        Task { @MainActor in
            let url = await camera.takePhoto()
            withAnimation(.easeOut(duration: 0.08)) { flash = true }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.35)) { flash = false; busy = false }
            guard let url else {
                HUD.show(L10n.Island.photoFailed, symbol: "exclamationmark.triangle")
                return
            }
            AppFeel.tap(.generic)
            HUD.show(L10n.Island.photoSaved, symbol: "camera.fill")
            withAnimation(.spring(duration: 0.35)) {
                lastPhoto = url
                thumbnail = NSImage(contentsOf: url)
            }
            // The thumbnail goes away after a few seconds.
            try? await Task.sleep(for: .seconds(4))
            if lastPhoto == url { withAnimation(.easeOut(duration: 0.3)) { thumbnail = nil } }
        }
    }
}
