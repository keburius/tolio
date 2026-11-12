import OmniCore
@testable import OmniPlatform
import Testing

struct PermissionStateMappingTests {
    @Test func trustedFlagMapping() {
        #expect(PermissionStateMapping.fromTrusted(true, everRequested: false) == .granted)
        #expect(PermissionStateMapping.fromTrusted(false, everRequested: false) == .notDetermined)
        #expect(PermissionStateMapping.fromTrusted(false, everRequested: true) == .denied)
    }

    @Test(arguments: [
        (0, PermissionState.notDetermined), (1, .denied), (2, .denied), (3, .granted), (99, .unknown),
    ])
    func avAuthorizationMapping(raw: Int, expected: PermissionState) {
        #expect(PermissionStateMapping.fromAVAuthorization(rawValue: raw) == expected)
    }

    @Test func fullDiskAccessHeuristic() {
        #expect(PermissionStateMapping.fullDiskAccess(probes: [.missing, .readable]) == .granted)
        #expect(PermissionStateMapping.fullDiskAccess(probes: [.permissionDenied, .missing]) == .denied)
        #expect(PermissionStateMapping.fullDiskAccess(probes: [.missing, .missing]) == .unknown)
        #expect(PermissionStateMapping.fullDiskAccess(probes: []) == .unknown)
    }
}
