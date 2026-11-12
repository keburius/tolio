import Testing
@testable import FeatureTextActions

struct SelectionGuardTests {
    private func context(_ bundleID: String? = "com.example.editor", _ edit: (inout SelectionGuard.Context) -> Void = { _ in }) -> SelectionGuard.Context {
        var c = SelectionGuard.Context(bundleID: bundleID)
        edit(&c)
        return c
    }

    /// The decision table: password-related rules win over everything else.
    @Test func decisionTable() {
        let rows: [(SelectionGuard.Context, SelectionGuard.Decision)] = [
            (context(), .accessibilityThenCopy),
            (context { $0.copyFallbackEnabled = false }, .accessibilityOnly),
            (context("com.apple.finder"), .accessibilityOnly),
            (context(nil), .skip(.noApp)),
            (context { $0.isOwnApp = true }, .skip(.ownApp)),
            (context { $0.secureInputEnabled = true }, .skip(.secureInput)),
            (context { $0.role = "AXSecureTextField" }, .skip(.passwordField)),
            (context { $0.role = "AXTextField"; $0.subrole = "AXSecureTextField" }, .skip(.passwordField)),
            (context("com.1password.1password"), .skip(.passwordManager)),
            (context("com.apple.Passwords"), .skip(.passwordManager)),
            (context { $0.userExcluded = ["com.example.editor"] }, .skip(.excludedApp)),
            // Secure input beats an excluded app and a disabled fallback.
            (context { $0.secureInputEnabled = true; $0.userExcluded = ["com.example.editor"]; $0.copyFallbackEnabled = false }, .skip(.secureInput)),
            // A password field in an app with fallback off is still skipped.
            (context { $0.copyFallbackEnabled = false; $0.subrole = "AXSecureTextField" }, .skip(.passwordField)),
            (context { $0.role = "AXTextArea" }, .accessibilityThenCopy),
        ]
        for (index, row) in rows.enumerated() {
            #expect(SelectionGuard.decide(row.0) == row.1, "row \(index)")
        }
    }
}
