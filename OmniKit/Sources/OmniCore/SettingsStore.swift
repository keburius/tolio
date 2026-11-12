import Foundation
import Observation

/// Typed key for a value in `SettingsStore`.
public struct SettingKey<Value: Codable & Sendable>: Sendable {
    public let name: String
    public let defaultValue: Value

    public init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }

    /// A key namespaced under a feature, e.g. `feature.clipboard.retentionDays`.
    public static func feature(_ id: FeatureID, _ name: String, default value: Value) -> SettingKey {
        SettingKey("feature.\(id.rawValue).\(name)", default: value)
    }
}

/// Persists `Codable` settings in UserDefaults as JSON.
///
/// Observable: SwiftUI views that read a value re-render when any value changes.
@MainActor
@Observable
public final class SettingsStore {
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let encoder = JSONEncoder()
    @ObservationIgnored private let decoder = JSONDecoder()
    @ObservationIgnored private let log = Log.logger("settings")
    /// Bumped on every write so observers of any value are notified.
    private var revision = 0

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns the stored value, or the key's default if missing or unreadable.
    public func value<Value>(_ key: SettingKey<Value>) -> Value {
        _ = revision
        guard let data = defaults.data(forKey: key.name) else { return key.defaultValue }
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            log.error("Unreadable setting \(key.name, privacy: .public); using default")
            return key.defaultValue
        }
    }

    public func set<Value>(_ value: Value, for key: SettingKey<Value>) {
        do {
            defaults.set(try encoder.encode(value), forKey: key.name)
            revision += 1
        } catch {
            log.error("Could not encode setting \(key.name, privacy: .public)")
        }
    }

    /// Removes the stored value so the default applies again.
    public func reset<Value>(_ key: SettingKey<Value>) {
        defaults.removeObject(forKey: key.name)
        revision += 1
    }
}
