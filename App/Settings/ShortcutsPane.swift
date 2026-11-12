import OmniCore
import OmniPlatform
import SwiftUI

/// All shortcuts registered by enabled features, rebindable.
struct ShortcutsPane: View {
    let hotkeys: HotkeyManager
    let features: FeatureRegistry

    var body: some View {
        Form {
            if hotkeys.registrations.isEmpty {
                Text("No enabled feature has shortcuts.").foregroundStyle(.secondary)
            }
            ForEach(groups, id: \.owner) { group in
                Section(features.feature(group.owner)?.displayName ?? group.owner.rawValue) {
                    ForEach(group.items) { registration in
                        row(registration)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var groups: [(owner: FeatureID, items: [HotkeyManager.Registration])] {
        Dictionary(grouping: hotkeys.sortedRegistrations, by: \.owner)
            .map { (owner: $0.key, items: $0.value) }
            .sorted { $0.owner.rawValue < $1.owner.rawValue }
    }

    private func row(_ registration: HotkeyManager.Registration) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(registration.action.title)
                if let problem = problem(registration.state) {
                    Text(problem).font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            HotkeyRecorderView(combo: combo(registration.state)) { newCombo in
                message(for: hotkeys.rebind(registration.id, to: newCombo))
            }
            Button {
                hotkeys.resetToDefault(registration.id)
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .help("Reset to default")
        }
    }

    private func combo(_ state: HotkeyManager.BindingState) -> KeyCombo? {
        switch state {
        case let .active(combo), let .conflict(combo, _), let .failed(combo, _): combo
        case .unbound: nil
        }
    }

    private func problem(_ state: HotkeyManager.BindingState) -> String? {
        switch state {
        case .active, .unbound: nil
        case let .conflict(_, other):
            "Inactive: same shortcut as \(hotkeys.registrations[other]?.action.title ?? other)."
        case .failed: "Inactive: another app already uses this shortcut."
        }
    }

    private func message(for result: HotkeyManager.RebindResult) -> String? {
        switch result {
        case .ok: nil
        case let .invalid(issue): issue.message
        case let .conflict(title): "Already used by “\(title)”."
        case .systemRefused: "Another app already uses this shortcut."
        }
    }
}
