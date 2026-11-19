import Foundation

/// The choices on the onboarding screens. Pure: nothing is turned on until `apply`.
public struct OnboardingModel: Sendable {
    public struct Option: Sendable, Identifiable {
        public let id: FeatureID
        public let required: Set<Permission>
        public let optional: Set<Permission>

        public init(id: FeatureID, required: Set<Permission>, optional: Set<Permission>) {
            self.id = id
            self.required = required
            self.optional = optional
        }
    }

    /// Clipboard History, Window Layouts, Energy Mode, Screenshots & Recording.
    public static let recommended: Set<FeatureID> = ["clipboard", "windows", "keepawake", "screenshots"]

    public let options: [Option]
    public var chosen: Set<FeatureID>

    public init(options: [Option], chosen: Set<FeatureID>? = nil) {
        self.options = options
        self.chosen = chosen ?? Self.recommended.intersection(options.map(\.id))
    }

    public mutating func chooseRecommended() { chosen = Self.recommended.intersection(options.map(\.id)) }
    public mutating func chooseEverything() { chosen = Set(options.map(\.id)) }
    public mutating func chooseNone() { chosen = [] }

    public mutating func set(_ on: Bool, _ id: FeatureID) {
        if on { chosen.insert(id) } else { chosen.remove(id) }
    }

    public var requiredPermissions: Set<Permission> {
        options.filter { chosen.contains($0.id) }.reduce(into: []) { $0.formUnion($1.required) }
    }

    public var optionalPermissions: Set<Permission> {
        options.filter { chosen.contains($0.id) }.reduce(into: Set<Permission>()) { $0.formUnion($1.optional) }
            .subtracting(requiredPermissions)
    }

    /// Features using `permission` among the chosen ones.
    public func users(of permission: Permission) -> [FeatureID] {
        options.filter { chosen.contains($0.id) && ($0.required.contains(permission) || $0.optional.contains(permission)) }.map(\.id)
    }

    /// The on/off changes needed to match the choice, given what's on now.
    public func changes(from current: Set<FeatureID>) -> [(FeatureID, Bool)] {
        options.compactMap { option in
            let want = chosen.contains(option.id)
            return want == current.contains(option.id) ? nil : (option.id, want)
        }
    }
}
