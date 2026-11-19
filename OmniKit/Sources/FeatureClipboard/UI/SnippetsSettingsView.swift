import OmniCore
import OmniPlatform
import SwiftUI

/// List, add, edit, and delete snippets.
struct SnippetsSettingsView: View {
    let settings: SettingsStore
    @State private var editing: Snippet?

    private var snippets: [Snippet] { settings.value(SnippetsFeature.snippetsKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                ASSection(L10n.Snippets.list) {
                    ForEach(snippets) { snippet in row(snippet) }
                    HStack(spacing: 12) {
                        if snippets.isEmpty {
                            Text(L10n.Snippets.empty)
                                .font(AS.font(12)).foregroundStyle(AS.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button(L10n.Snippets.addSnippet, action: addSnippet)
                            .buttonStyle(.asSecondary)
                            .settingsAnchor(SnippetsFeature.Anchor.list)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                }
                ASFootnote(L10n.Snippets.placeholdersHelp)
                    .settingsAnchor(SnippetsFeature.Anchor.placeholders)
            }
        }
        .sheet(item: $editing) { snippet in
            SnippetEditor(snippet: snippet, others: snippets) { saved in
                if snippets.contains(where: { $0.id == saved.id }) {
                    update(saved.id) { $0 = saved }
                } else {
                    save(snippets + [saved])
                }
                editing = nil
            } onCancel: {
                editing = nil
            }
        }
    }

    private func row(_ snippet: Snippet) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.title).font(AS.body).foregroundStyle(AS.text).lineLimit(1)
                Text(snippet.abbreviation).font(AS.font(11.5).monospaced()).foregroundStyle(AS.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(L10n.Snippets.edit) { editing = snippet }
                .buttonStyle(.asSecondary)
            Button { save(snippets.filter { $0.id != snippet.id }) } label: {
                LineIcon("M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.7 8.5h5.6l.7-8.5", size: 14, color: AS.textSecondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.Snippets.delete)
            .accessibilityLabel(L10n.Snippets.delete)
            ASSwitch(L10n.Snippets.enabledToggle(snippet.title), isOn: Binding(
                get: { snippet.isEnabled },
                set: { enabled in update(snippet.id) { $0.isEnabled = enabled } }
            ))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
    }

    /// Opens the editor for a new snippet.
    private func addSnippet() {
        editing = Snippet(abbreviation: "", title: "", body: "")
    }

    private func update(_ id: UUID, _ change: (inout Snippet) -> Void) {
        var all = snippets
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        change(&all[index])
        save(all)
    }

    private func save(_ all: [Snippet]) {
        settings.set(all, for: SnippetsFeature.snippetsKey)
    }
}

/// The example at the top of the Snippets page: a typed code and the text
/// it turns into.
struct SnippetsHero: View {
    var body: some View {
        ASStage(tint: AS.blue) {
            HStack(spacing: 18) {
                card {
                    HStack(spacing: 1) {
                        Text(L10n.Snippets.codePrompt)
                            .font(AS.font(17, .semibold).monospaced())
                            .foregroundStyle(AS.text)
                        Rectangle().fill(AS.blue).frame(width: 2, height: 20)
                    }
                }
                LineIcon("M3 8h10M9 4l4 4-4 4", size: 22, lineWidth: 2, color: Color(hex: 0x2E92FF))
                card {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Snippets.heroExpanded)
                        Text(L10n.Snippets.heroName)
                    }
                    .font(AS.font(15, .medium))
                    .foregroundStyle(AS.text)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Snippets.heroDescription)
        .accessibilityAddTraits(.isImage)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(.horizontal, 18)
            .frame(minWidth: 120, minHeight: 76)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AS.panel))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 12)
    }
}

private struct SnippetEditor: View {
    @State var snippet: Snippet
    let others: [Snippet]
    let onSave: (Snippet) -> Void
    let onCancel: () -> Void

    var body: some View {
        let problem = Snippet.problem(with: snippet.abbreviation, among: others, editing: snippet.id)
        Form {
            TextField(L10n.Snippets.code, text: $snippet.abbreviation, prompt: Text(L10n.Snippets.codePrompt))
            if let problem, !snippet.abbreviation.isEmpty {
                Text(problem).font(.caption).foregroundStyle(.red)
            }
            TextField(L10n.Snippets.title, text: $snippet.title)
            TextEditor(text: $snippet.body)
                .font(.body.monospaced())
                .frame(minHeight: 140)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L10n.Common.cancel, action: onCancel) }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Snippets.save) {
                    if snippet.title.isEmpty { snippet.title = snippet.abbreviation }
                    onSave(snippet)
                }
                .disabled(problem != nil || snippet.body.isEmpty)
            }
        }
    }
}
