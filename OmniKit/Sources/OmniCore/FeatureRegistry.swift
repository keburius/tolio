import Observation

/// Owns all features, persists which ones the user wants on, and starts or
/// stops them while respecting their permission requirements.
@MainActor
@Observable
public final class FeatureRegistry {
    /// Runtime state of one feature.
    public enum Status: Equatable, Sendable {
        case off
        case running
        /// Wanted by the user but blocked until these permissions are granted.
        case waitingForPermissions(Set<Permission>)
        case failed(String)
    }

    public static let wantedKey = SettingKey<[String: Bool]>("features.wanted", default: [:])

    public private(set) var features: [any Feature] = []
    public private(set) var statuses: [FeatureID: Status] = [:]

    @ObservationIgnored private var lifetimes: [FeatureID: Lifetime] = [:]
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let permissions: any PermissionChecking
    @ObservationIgnored private let hotkeys: any HotkeyRegistering
    @ObservationIgnored private let commands: any CommandRegistering
    @ObservationIgnored private let log = Log.logger("features")

    public init(
        settings: SettingsStore,
        permissions: any PermissionChecking,
        hotkeys: any HotkeyRegistering,
        commands: any CommandRegistering
    ) {
        self.settings = settings
        self.permissions = permissions
        self.hotkeys = hotkeys
        self.commands = commands
    }

    /// Adds a feature. It stays off until `activateWantedFeatures()` or `setWanted`.
    public func register(_ feature: any Feature) {
        precondition(self.feature(feature.id) == nil, "Duplicate feature id \(feature.id)")
        features.append(feature)
        statuses[feature.id] = .off
    }

    public func feature(_ id: FeatureID) -> (any Feature)? {
        features.first { $0.id == id }
    }

    public func status(of id: FeatureID) -> Status {
        statuses[id] ?? .off
    }

    /// The user's persisted choice, falling back to the feature's default.
    public func isWanted(_ id: FeatureID) -> Bool {
        if let stored = settings.value(Self.wantedKey)[id.rawValue] { return stored }
        return feature(id)?.isEnabledByDefault ?? false
    }

    /// Persists the user's choice and starts or stops the feature.
    public func setWanted(_ wanted: Bool, for id: FeatureID) {
        var map = settings.value(Self.wantedKey)
        map[id.rawValue] = wanted
        settings.set(map, for: Self.wantedKey)
        if wanted { activate(id) } else { deactivate(id) }
    }

    /// Starts every wanted feature that isn't running. Call at launch and
    /// whenever permission states change.
    public func activateWantedFeatures() {
        for feature in features where isWanted(feature.id) && status(of: feature.id) != .running {
            activate(feature.id)
        }
    }

    /// Stops all running features, e.g. at quit.
    public func deactivateAll() {
        for feature in features { deactivate(feature.id) }
    }

    /// Union of required permissions of all wanted features.
    public var permissionsForWantedFeatures: Set<Permission> {
        features.filter { isWanted($0.id) }.reduce(into: []) { $0.formUnion($1.requiredPermissions) }
    }

    /// Union of optional permissions of all wanted features, minus required ones.
    public var optionalPermissionsForWantedFeatures: Set<Permission> {
        features.filter { isWanted($0.id) }
            .reduce(into: Set<Permission>()) { $0.formUnion($1.optionalPermissions) }
            .subtracting(permissionsForWantedFeatures)
    }

    private func activate(_ id: FeatureID) {
        guard let feature = feature(id), status(of: id) != .running else { return }
        let missing = permissions.missing(feature.requiredPermissions)
        guard missing.isEmpty else {
            statuses[id] = .waitingForPermissions(missing)
            return
        }
        let lifetime = Lifetime()
        let context = FeatureContext(
            featureID: id, settings: settings, permissions: permissions,
            hotkeys: hotkeys, commands: commands, lifetime: lifetime
        )
        do {
            try feature.enable(context: context)
            lifetimes[id] = lifetime
            statuses[id] = .running
            log.info("Enabled \(id.rawValue, privacy: .public)")
        } catch {
            releaseResources(of: id, lifetime: lifetime)
            statuses[id] = .failed(String(describing: error))
            log.error("Failed to enable \(id.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }

    private func deactivate(_ id: FeatureID) {
        guard let feature = feature(id) else { return }
        if status(of: id) == .running {
            feature.disable()
            log.info("Disabled \(id.rawValue, privacy: .public)")
        }
        releaseResources(of: id, lifetime: lifetimes.removeValue(forKey: id))
        statuses[id] = .off
    }

    private func releaseResources(of id: FeatureID, lifetime: Lifetime?) {
        lifetime?.cancelAll()
        hotkeys.unregisterAll(owner: id)
        commands.unregisterAll(owner: id)
    }
}
