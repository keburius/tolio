import OmniCore
import OmniPlatform
import SwiftUI
import UniformTypeIdentifiers

/// Which quick-access icons show, their order, or one icon only.
struct MenuBarPane: View {
    let services: AppServices
    let entries: () -> [QuickAccessID: MenuBarController.Entry]
    @State private var dragging: QuickAccessID?

    private var config: MenuBarConfiguration { services.settings.value(MenuBarConfiguration.key) }

    private func update(_ change: (inout MenuBarConfiguration) -> Void) {
        var copy = config
        change(&copy)
        services.settings.set(copy, for: MenuBarConfiguration.key)
    }

    var body: some View {
        let all = entries()
        let single = config.mode == .single
        PageScaffold(L10n.SettingsUI.menuBar) {
            VStack(alignment: .leading, spacing: 6) {
                ASSectionTitle(L10n.SettingsUI.iconsInMenuBar)
                HStack(spacing: 12) {
                    modeCard(.separate, L10n.MenuBarUI.separateIcons, L10n.MenuBarUI.separateIconsDetail)
                    modeCard(.single, L10n.MenuBarUI.oneIcon, L10n.MenuBarUI.oneIconDetail)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(L10n.SettingsUI.iconsInMenuBar)
            }
            .settingsAnchor("menubar.mode")

            VStack(alignment: .leading, spacing: 6) {
                ASSectionTitle(L10n.SettingsUI.quickActions)
                ASCard {
                    ASDividedStack {
                        ForEach(config.entries, id: \.id) { entry in
                            if let info = all[entry.id] { row(entry, info) }
                        }
                    }
                }
                .disabled(single)
                .opacity(single ? 0.5 : 1)
                ASFootnote(L10n.SettingsUI.quickActionsHelp)
            }
            .settingsAnchor("menubar.items")

            ASCard(padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    note(L10n.MenuBarUI.statsNote)
                    note(L10n.SettingsUI.notchNote)
                }
            }

            HStack {
                Spacer()
                Button(L10n.SettingsUI.resetToDefaults) { services.settings.reset(MenuBarConfiguration.key) }
                    .buttonStyle(.asSecondary)
            }
        }
    }

    // MARK: Mode

    private func modeCard(_ mode: MenuBarConfiguration.Mode, _ title: String, _ detail: String) -> some View {
        let selected = config.mode == mode
        let shape = RoundedRectangle(cornerRadius: AS.cardRadius, style: .continuous)
        return Button {
            update { $0.mode = mode }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // A miniature menu bar.
                HStack(spacing: 7) {
                    Spacer(minLength: 0)
                    if mode == .separate {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(AS.textSecondary).frame(width: 10, height: 10)
                        }
                    }
                    Image("MenuBarIcon").renderingMode(.template).resizable().scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundStyle(AS.text)
                }
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(AS.fieldFill))
                .accessibilityHidden(true)
                HStack(spacing: 8) {
                    radio(selected)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(AS.text)
                        Text(detail).font(AS.footnote).foregroundStyle(AS.textTertiary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(AS.cardFill))
            .overlay(shape.strokeBorder(selected ? AS.blue : Color.white.opacity(0.08), lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder private func radio(_ selected: Bool) -> some View {
        if selected {
            Circle().fill(.white)
                .overlay(Circle().strokeBorder(AS.blue, lineWidth: 4))
                .frame(width: 14, height: 14)
        } else {
            Circle().strokeBorder(Color(hex: 0x8E8E93), lineWidth: 1.5).frame(width: 14, height: 14)
        }
    }

    // MARK: Quick actions

    private func row(_ entry: MenuBarConfiguration.Entry, _ info: MenuBarController.Entry) -> some View {
        let isOn = services.features.status(of: info.feature.id) == .running
        return HStack(spacing: 10) {
            LineIcon("M3 5.5h10M3 8h10M3 10.5h10", size: 12, lineWidth: 1.6, color: Color(hex: 0x8E8E93))
                .help(L10n.MenuBarUI.dragToReorder)
                .accessibilityHidden(true)
            CheckBox(label: info.item.title, isOn: Binding(
                get: { entry.isVisible },
                set: { visible in update { $0.setVisible(visible, for: entry.id) } }
            ))
            FeatureIcon(info.feature.id, size: 22, fallbackSymbol: info.item.symbolName)
            Text(info.item.title)
                .font(AS.body).foregroundStyle(AS.text).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isOn {
                Text(Self.capitalizedFirst(info.item.clickHint))
                    .font(.system(size: 12)).foregroundStyle(AS.textTertiary).lineLimit(1)
                    .accessibilityLabel(L10n.SettingsUI.clickDoes(info.item.clickHint))
            } else {
                Text(L10n.App.featureIsOff(info.feature.displayName))
                    .font(.system(size: 12)).foregroundStyle(AS.textTertiary).lineLimit(1)
                Button(L10n.Common.turnOn) { services.features.setWanted(true, for: info.feature.id) }
                    .buttonStyle(ASButtonStyle(.secondary, height: 22, fontSize: 12))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(dragging == entry.id ? Color.white.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onDrag {
            dragging = entry.id
            return NSItemProvider(object: entry.id.rawValue as NSString)
        }
        .onDrop(of: [UTType.text], delegate: ReorderDrop(target: entry.id, dragging: $dragging) { from, target in
            update { configuration in
                guard let fromIndex = configuration.entries.firstIndex(where: { $0.id == from }),
                      let toIndex = configuration.entries.firstIndex(where: { $0.id == target }) else { return }
                configuration.move(from, by: toIndex - fromIndex)
            }
        })
        .contextMenu {
            Button(L10n.SettingsUI.moveLeft) { update { $0.move(entry.id, by: -1) } }
            Button(L10n.SettingsUI.moveRight) { update { $0.move(entry.id, by: 1) } }
        }
        .accessibilityAction(named: Text(L10n.SettingsUI.moveLeft)) { update { $0.move(entry.id, by: -1) } }
        .accessibilityAction(named: Text(L10n.SettingsUI.moveRight)) { update { $0.move(entry.id, by: 1) } }
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            LineIcon("M8 2a6 6 0 1 0 .01 0M8 7.5v3.5M8 5h.01", size: 13, lineWidth: 1.6, color: AS.textTertiary)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 12)).lineSpacing(3).foregroundStyle(AS.icon)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).localizedUppercase + text.dropFirst()
    }
}

/// The design's 16 pt checkbox: blue with a white check when on.
private struct CheckBox: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn).toggleStyle(CheckBoxStyle()).labelsHidden()
    }
}

private struct CheckBoxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack {
                shape.fill(configuration.isOn ? AS.blue : AS.fieldFill)
                shape.strokeBorder(configuration.isOn ? AS.blue : Color.white.opacity(0.22), lineWidth: 1)
                if configuration.isOn {
                    LineIcon("M3.5 8.5l3 3 6-7", size: 10, lineWidth: 2.4, color: .white)
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

/// Moves the dragged quick action to where the pointer is as it passes over rows.
private struct ReorderDrop: DropDelegate {
    let target: QuickAccessID
    @Binding var dragging: QuickAccessID?
    let move: (_ from: QuickAccessID, _ to: QuickAccessID) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        if let animation = OmniStyle.motion() {
            withAnimation(animation) { move(dragging, target) }
        } else {
            move(dragging, target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
