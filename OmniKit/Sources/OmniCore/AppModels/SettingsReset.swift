import Foundation

/// Which stored keys "Reset to Defaults" removes for a feature.
public enum SettingsReset {
    /// Keys under `feature.<id>.` except the user's own content.
    public static func keysToRemove(feature id: FeatureID, storedKeys: some Sequence<String>, keep userContent: Set<String>) -> [String] {
        let prefix = "feature.\(id.rawValue)."
        return storedKeys.filter { $0.hasPrefix(prefix) && !userContent.contains($0) }.sorted()
    }
}
