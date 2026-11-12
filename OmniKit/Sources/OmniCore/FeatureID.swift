/// Stable identifier of a feature. Used as a settings key and as the owner of
/// hotkeys and commands the feature registers.
public struct FeatureID: RawRepresentable, Hashable, Codable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public var description: String { rawValue }
}
