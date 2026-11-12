import OmniCore

/// Pure mapping from raw OS answers to `PermissionState`. Kept separate from
/// `PermissionsManager` so it can be unit-tested.
public enum PermissionStateMapping {
    /// For APIs that only answer yes/no (Accessibility, Screen Recording).
    public static func fromTrusted(_ trusted: Bool, everRequested: Bool) -> PermissionState {
        if trusted { return .granted }
        return everRequested ? .denied : .notDetermined
    }

    /// `AVAuthorizationStatus` raw values: 0 notDetermined, 1 restricted, 2 denied, 3 authorized.
    public static func fromAVAuthorization(rawValue: Int) -> PermissionState {
        switch rawValue {
        case 0: .notDetermined
        case 1, 2: .denied
        case 3: .granted
        default: .unknown
        }
    }
}
