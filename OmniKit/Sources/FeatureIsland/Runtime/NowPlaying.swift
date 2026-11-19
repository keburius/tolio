import AppKit
import Observation
import OmniCore
import SwiftUI

/// What Music or Spotify is playing. Track changes come from the
/// notifications both apps broadcast on the Mac (no permission needed).
/// Position, artwork and the controls use Apple Events, which macOS asks
/// about once per app ("Tolio wants to control Music"). Spotify's cover art
/// is downloaded from Spotify's own image server (the URL Spotify reports);
/// nothing else goes online.
@MainActor
@Observable
final class NowPlaying {
    enum Player: String, CaseIterable {
        case music = "com.apple.Music"
        case spotify = "com.spotify.client"

        var appName: String { self == .music ? "Music" : "Spotify" } // l10n-ignore
        var notification: String { self == .music ? "com.apple.Music.playerInfo" : "com.spotify.client.PlaybackStateChanged" }
    }

    struct Track: Equatable {
        var title: String
        var artist: String
        var album: String
        var duration: TimeInterval
    }

    private(set) var player: Player?
    private(set) var track: Track?
    private(set) var isPlaying = false
    private(set) var artwork: NSImage? {
        didSet { accent = artwork.flatMap(Self.averageColor) ?? Self.defaultAccent }
    }
    /// A bright version of the artwork's main color, for the sound bars.
    private(set) var accent: Color = NowPlaying.defaultAccent
    static let defaultAccent = Color(red: 0.98, green: 0.36, blue: 0.42)
    private(set) var shuffle = false
    /// Position at `positionDate`; the view adds the time since while playing.
    private(set) var position: TimeInterval = 0
    private(set) var positionDate = Date()

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var refresher: Task<Void, Never>?

    var hasTrack: Bool { track != nil }

    func start() {
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        for player in Player.allCases {
            observers.append(center.addObserver(forName: Notification.Name(player.notification), object: nil, queue: .main) { [weak self] note in
                let info = PlayerInfo(note.userInfo as? [String: Any] ?? [:], player: player)
                MainActor.assumeIsolated { self?.received(info, from: player) }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                if let self, id == self.player?.rawValue { self.clear() }
            }
        })
        // Already playing when Tolio starts? (Asked in the background: if
        // macOS is still waiting for you to allow control, nothing freezes.)
        Task { @MainActor [weak self] in
            // Playing first; otherwise a paused song still shows (wings with a pause icon).
            var paused: Player?
            for player in Player.allCases where Self.isRunning(player) {
                let state = await Scripts.query("player state as string", player)
                if state == "paused", paused == nil { paused = player }
                if state == "playing" {
                    guard let self, self.player == nil else { return }
                    self.player = player
                    await self.refreshFromScript()
                    return
                }
            }
            if let paused, let self, self.player == nil {
                self.player = paused
                await self.refreshFromScript()
            }
        }
    }

    func stop() {
        observers.forEach {
            DistributedNotificationCenter.default().removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        observers.removeAll()
        refresher?.cancel()
    }

    /// Keeps the position fresh while the island is open.
    func setLive(_ live: Bool) {
        refresher?.cancel()
        guard live else { return }
        refresher = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.refreshPosition()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: Controls

    func playPause() {
        guard let player else { return }
        Scripts.send("playpause", player)
        isPlaying.toggle()
        positionDate = Date()
    }

    func next() { command("next track") }
    func previous() { command("previous track") }

    func toggleShuffle() {
        guard let player else { return }
        let property = player == .music ? "shuffle enabled" : "shuffling"
        Scripts.send("set \(property) to not \(property)", player)
        shuffle.toggle()
    }

    func seek(to seconds: TimeInterval) {
        guard let player else { return }
        Scripts.send("set player position to \(max(0, seconds))", player)
        position = seconds
        positionDate = Date()
    }

    /// Brings the playing app forward.
    func openPlayer() {
        guard let player, let app = NSRunningApplication.runningApplications(withBundleIdentifier: player.rawValue).first else { return }
        app.activate()
    }

    func currentPosition(at date: Date) -> TimeInterval {
        let elapsed = isPlaying ? date.timeIntervalSince(positionDate) : 0
        return min(position + elapsed, track?.duration ?? .infinity)
    }

    // MARK: Updates

    private func received(_ info: PlayerInfo, from player: Player) {
        let state = info.state
        if state == "stopped" {
            if self.player == player { clear() }
            return
        }
        // Another app's pause shouldn't steal the island from what's playing.
        if self.player != nil, self.player != player, isPlaying, state != "playing" { return }
        self.player = player
        isPlaying = state == "playing"
        let newTrack = Track(title: info.title, artist: info.artist, album: info.album, duration: info.duration)
        let changed = newTrack.title != track?.title || newTrack.artist != track?.artist
        track = newTrack
        if let seconds = info.position {
            position = seconds
            positionDate = Date()
        }
        Task { @MainActor [weak self] in
            if changed { await self?.refreshFromScript() } else { await self?.refreshPosition() }
        }
    }

    private func refreshFromScript() async {
        guard let player else { return }
        if track == nil {
            let title = await Scripts.query("name of current track", player) ?? ""
            guard !title.isEmpty else { return }
            let artist = await Scripts.query("artist of current track", player) ?? ""
            let album = await Scripts.query("album of current track", player) ?? ""
            let duration = Double(await Scripts.query("duration of current track", player) ?? "") ?? 0
            track = Track(title: title, artist: artist, album: album, duration: duration / (player == .spotify ? 1000 : 1))
            isPlaying = await Scripts.query("player state as string", player) == "playing"
        }
        shuffle = await Scripts.query(player == .music ? "shuffle enabled" : "shuffling", player) == "true"
        await refreshPosition()
        let current = track
        if player == .music, let data = await Scripts.musicArtwork(), let image = NSImage(data: data) {
            artwork = image
        } else if player == .spotify, let image = await spotifyArtwork() {
            // A slow download mustn't put the old cover on a newer song.
            guard track == current else { return }
            artwork = image
        } else {
            artwork = Self.appIcon(player)
        }
    }

    /// Recent Spotify covers by URL, so replaying or pausing doesn't download again.
    @ObservationIgnored private var spotifyCovers: [URL: NSImage] = [:]

    private func spotifyArtwork() async -> NSImage? {
        guard let text = await Scripts.query("artwork url of current track", .spotify),
              let url = Self.spotifyImageURL(text) else { return nil }
        if let cached = spotifyCovers[url] { return cached }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 8)
        request.setValue(nil, forHTTPHeaderField: "Cookie")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, let image = NSImage(data: data) else { return nil }
        if spotifyCovers.count > 30 { spotifyCovers.removeAll() }
        spotifyCovers[url] = image
        return image
    }

    /// Only https images on Spotify's own image servers are fetched.
    nonisolated static func spotifyImageURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme == "https",
              let host = url.host?.lowercased(),
              host == "scdn.co" || host.hasSuffix(".scdn.co") || host.hasSuffix(".spotifycdn.com") else { return nil }
        return url
    }

    private func refreshPosition() async {
        guard let player, let value = await Scripts.query("player position", player),
              let seconds = Double(value.replacingOccurrences(of: ",", with: ".")) else { return }
        position = seconds
        positionDate = Date()
    }

    private func clear() {
        player = nil
        track = nil
        isPlaying = false
        artwork = nil
    }

    private func command(_ verb: String) {
        guard let player else { return }
        Scripts.send(verb, player)
    }

    // MARK: Apple Events

    static func isRunning(_ player: Player) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: player.rawValue).isEmpty
    }

    /// The image's average color, lifted so it shows on black.
    static func averageColor(_ image: NSImage) -> Color? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let color = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &sat, brightness: &b, alpha: &a)
        // Grey artwork keeps the default pink.
        guard sat > 0.12 else { return nil }
        return Color(hue: h, saturation: min(max(sat, 0.45), 0.85), brightness: max(b, 0.85))
    }

    private static func appIcon(_ player: Player) -> NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.rawValue).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}

/// The parts of a player's broadcast the island uses, copied out as plain values.
struct PlayerInfo: Sendable, Equatable {
    var state: String
    var title: String
    var artist: String
    var album: String
    /// Seconds.
    var duration: TimeInterval
    /// Seconds (Spotify sends it; Music doesn't).
    var position: TimeInterval?

    init(_ info: [String: Any], player: NowPlaying.Player) {
        func number(_ key: String) -> Double? {
            (info[key] as? Double) ?? (info[key] as? Int).map(Double.init) ?? (info[key] as? NSNumber)?.doubleValue
        }
        state = (info["Player State"] as? String)?.lowercased() ?? ""
        title = info["Name"] as? String ?? ""
        artist = info["Artist"] as? String ?? ""
        album = info["Album"] as? String ?? ""
        // Both apps send milliseconds.
        duration = (number(player == .music ? "Total Time" : "Duration") ?? 0) / 1000
        position = number("Playback Position")
    }
}

/// Apple Events to Music and Spotify, run one at a time on a background
/// queue so a slow app (or the "allow Tolio to control…" question) can never
/// freeze Tolio. Never launches a player: if it isn't running, nothing is sent.
enum Scripts {
    private static let queue = DispatchQueue(label: "com.george.tolio.island.scripts", qos: .userInitiated)

    /// `get <body>` from the player; nil if it isn't running or refused.
    static func query(_ body: String, _ player: NowPlaying.Player) async -> String? {
        await run("tell application id \"\(player.rawValue)\" to get \(body)", player: player).map { $0.stringValue ?? "" }
    }

    /// Sends a command without waiting.
    static func send(_ body: String, _ player: NowPlaying.Player) {
        let source = "tell application id \"\(player.rawValue)\" to \(body)"
        let id = player.rawValue
        queue.async {
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty else { return }
            var error: NSDictionary?
            _ = NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    /// The current Music track's artwork, as image data.
    static func musicArtwork() async -> Data? {
        await run("tell application id \"com.apple.Music\" to get raw data of artwork 1 of current track", player: .music)?.data
    }

    private static func run(_ source: String, player: NowPlaying.Player) async -> Result? {
        let id = player.rawValue
        return await withCheckedContinuation { continuation in
            queue.async {
                guard !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                var error: NSDictionary?
                let descriptor = NSAppleScript(source: source)?.executeAndReturnError(&error)
                continuation.resume(returning: error == nil ? descriptor.map { Result(stringValue: $0.stringValue, data: $0.data) } : nil)
            }
        }
    }

    struct Result: Sendable {
        var stringValue: String?
        var data: Data
    }
}
