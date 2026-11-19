import AppKit
import OmniCore

/// App-wide trackpad taps and tick sounds (Settings → General → Feel).
/// Features call these instead of the haptic performer or NSSound directly.
@MainActor
public enum AppFeel {
    public static let hapticsKey = SettingKey("app.feel.haptics", default: true)
    public static let ticksKey = SettingKey("app.feel.ticks", default: false)

    /// A light trackpad tap, if Haptic taps is on.
    public static func tap(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        guard isOn(hapticsKey) else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    /// A tap plus a soft tick sound when Tick sounds is on. Ticks closer than
    /// 45 ms are dropped so a fast drag doesn't buzz.
    public static func tick() {
        tap()
        guard isOn(ticksKey), Date().timeIntervalSince(lastTick) > 0.045, let sound = tickSound else { return }
        lastTick = Date()
        sound.stop()
        sound.play()
    }

    /// Whether tick sounds are on (for features with their own sound option).
    public static var ticksEnabled: Bool { isOn(ticksKey) }

    private static var lastTick = Date.distantPast
    private static let tickSound: NSSound? = {
        let sound = NSSound(named: "Tink")?.copy() as? NSSound
        sound?.volume = 0.15
        return sound
    }()

    /// Reads the stored JSON Bool the same way `SettingsStore` writes it.
    private static func isOn(_ key: SettingKey<Bool>) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: key.name),
              let value = try? JSONDecoder().decode(Bool.self, from: data) else { return key.defaultValue }
        return value
    }
}
