@testable import OmniCore
import Testing

struct PermissionTests {
    @Test(arguments: Permission.allCases)
    func everyPermissionHasASettingsDeepLink(permission: Permission) {
        #expect(permission.settingsURL.scheme == "x-apple.systempreferences")
        #expect(permission.settingsURL.absoluteString.hasSuffix(permission.settingsAnchor))
    }

    @Test func onlyGrantedAndUnknownAllowUse() {
        #expect(PermissionState.granted.allowsUse)
        #expect(PermissionState.unknown.allowsUse)
        #expect(!PermissionState.denied.allowsUse)
        #expect(!PermissionState.notDetermined.allowsUse)
    }
}
