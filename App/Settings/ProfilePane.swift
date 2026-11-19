import OmniCore
import OmniPlatform
import SwiftUI

/// The app, its plan and license, and where its source lives.
///
/// All Set has no licensing back end yet, so the plan is always Free and the
/// trial, activation and restore buttons say so instead of pretending.
struct ProfilePane: View {
    let services: AppServices
    @State private var licenseKey = ""
    @State private var notice: String?

    static let sourceURL = URL(string: "https://github.com/keburius/tolio")! // l10n-ignore

    var body: some View {
        PageScaffold(L10n.AllSet.profile) {
            identity
            ASSection(L10n.AllSet.pro) {
                ASRow(L10n.AllSet.pro, subtitle: L10n.AllSet.proPrice) {
                    Button(L10n.AllSet.startTrial) { notice = L10n.AllSet.licenseNotAvailable }
                        .buttonStyle(ProButtonStyle())
                }
                ASRow(L10n.AllSet.trialTitle, subtitle: L10n.AllSet.trialDetail)
            }
            ASSection(L10n.AllSet.license) {
                ASRow(L10n.AllSet.licenseKey) {
                    TextField(L10n.AllSet.licenseKey, text: $licenseKey, prompt: Text(verbatim: "XXXX-XXXX-XXXX-XXXX").foregroundStyle(AS.textTertiary)) // l10n-ignore
                        .textFieldStyle(.plain)
                        .font(AS.body)
                        .padding(.horizontal, 8)
                        .frame(width: 220, height: 26)
                        .background(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).fill(Color.black.opacity(0.25)))
                        .overlay(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                        .labelsHidden()
                        .onSubmit(activate)
                    Button(L10n.AllSet.activate, action: activate)
                        .buttonStyle(.asSecondary)
                        .disabled(licenseKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ASRow(L10n.AllSet.haveLicense, subtitle: L10n.AllSet.haveLicenseDetail) {
                    Button(L10n.AllSet.restore) { notice = L10n.AllSet.licenseNotAvailable }.buttonStyle(.asSecondary)
                }
            }
            if let notice {
                ASFootnote(notice)
            }
            ASSection(L10n.AllSet.about) {
                ASRow(L10n.AllSet.openSource, subtitle: L10n.AllSet.openSourceDetail) {
                    Link(L10n.AllSet.viewOnGitHub, destination: Self.sourceURL)
                        .font(AS.body)
                        .foregroundStyle(Color(hex: 0xB4ABFF))
                }
                ASRow(L10n.SettingsUI.version) {
                    Text(Bundle.main.versionString).font(AS.body).monospacedDigit().foregroundStyle(AS.textSecondary)
                }
            }
            HStack(spacing: 6) {
                LineIcon(ASIcon.lock, size: 11, lineWidth: 1.8)
                Text(L10n.AllSet.noTracking)
            }
            .font(AS.font(12))
            .foregroundStyle(AS.textSecondary)
            .padding(.leading, 12)
        }
    }

    private var identity: some View {
        HStack(spacing: 16) {
            AllSetLogo(size: 64)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(L10n.AllSet.appName).font(AS.heroTitle).tracking(-0.2).foregroundStyle(AS.text)
                    Text(L10n.AllSet.free)
                        .font(AS.font(11, .semibold))
                        .foregroundStyle(AS.icon)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AS.controlFill))
                }
                Text(L10n.AllSet.noAccount).font(AS.body).foregroundStyle(AS.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AS.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(AS.cardBorder, lineWidth: 1))
    }

    private func activate() {
        let key = licenseKey.trimmingCharacters(in: .whitespaces).uppercased()
        guard !key.isEmpty else { return }
        let groups = key.split(separator: "-", omittingEmptySubsequences: false)
        let wellFormed = groups.count == 4 && groups.allSatisfy { $0.count == 4 && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } }
        notice = wellFormed ? L10n.AllSet.licenseNotAvailable : L10n.AllSet.licenseInvalid
    }
}

/// The violet "Start 14-day trial" button.
private struct ProButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AS.font(13, .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: AS.controlRadius, style: .continuous).fill(Color(hex: 0x6A5AF0)))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
