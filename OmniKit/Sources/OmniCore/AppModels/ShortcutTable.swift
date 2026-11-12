import Foundation

/// Every shortcut of every feature (on or off) with its conflicts, for
/// Settings → Shortcuts. Pure, so conflicts are tested.
public struct ShortcutTable: Sendable {
    public struct Source: Sendable {
        public let action: HotkeyAction
        public let featureID: FeatureID
        public let featureName: String
        public let featureIsOn: Bool

        public init(action: HotkeyAction, featureID: FeatureID, featureName: String, featureIsOn: Bool) {
            self.action = action
            self.featureID = featureID
            self.featureName = featureName
            self.featureIsOn = featureIsOn
        }
    }

    public enum Status: Equatable, Sendable {
        case ok
        case unassigned
        /// Same shortcut as another Omni action. `otherIsOn` false means it
        /// will only clash once that feature is turned on.
        case conflict(otherTitle: String, otherIsOn: Bool)
        /// macOS refused it, usually because another app uses it.
        case usedByAnotherApp
    }

    public struct Row: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let featureID: FeatureID
        public let featureName: String
        public let featureIsOn: Bool
        public let combo: KeyCombo?
        public let isDefault: Bool
        public let status: Status
    }

    public let rows: [Row]

    /// - Parameters:
    ///   - bindings: the user's overrides.
    ///   - refused: action IDs macOS refused to register.
    public init(sources: [Source], bindings: HotkeyBindings, refused: Set<String> = []) {
        let combos = sources.map { bindings.combo(for: $0.action) }
        rows = sources.enumerated().map { index, source in
            let combo = combos[index]
            var status: Status = combo == nil ? .unassigned : .ok
            if let combo {
                if let other = sources.indices.first(where: { $0 != index && combos[$0] == combo }) {
                    status = .conflict(otherTitle: sources[other].action.title, otherIsOn: sources[other].featureIsOn)
                } else if refused.contains(source.action.id) {
                    status = .usedByAnotherApp
                }
            }
            return Row(
                id: source.action.id, title: source.action.title, featureID: source.featureID,
                featureName: source.featureName, featureIsOn: source.featureIsOn, combo: combo,
                isDefault: bindings.overrides[source.action.id] == nil, status: status
            )
        }
    }

    public var conflictCount: Int {
        rows.filter { if case .conflict = $0.status { true } else { false } }.count
    }

    /// The action that already uses `combo`, if any (to warn before rebinding).
    public func owner(of combo: KeyCombo, excluding id: String) -> Row? {
        rows.first { $0.id != id && $0.combo == combo }
    }
}
