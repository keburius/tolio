import OmniCore
import OmniPlatform
import SwiftUI

/// List, add, edit, and delete snippets.
struct SnippetsSettingsView: View {
    let settings: SettingsStore
    @State private var editing: Snippet?

    private var snippets: [Snippet] { settings.value(SnippetsFeature.snippetsKey) }

    var body: some View {
        Group {
            if snippets.isEmpty {
                EmptyState(
                    symbol: "text.badge.plus", message: L10n.Snippets.empty,
                    actionTitle: L10n.Snippets.addSnippet, action: addSnippet
                )
                .settingsAnchor(SnippetsFeature.Anchor.list)
            }
            ForEach(snippets) { snippet in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { snippet.isEnabled },
                        set: { enabled in update(snippet.id) { $0.isEnabled = enabled } }
                    ))
                    .labelsHidden()
                    .accessibilityLabel(L10n.Snippets.enabledToggle(snippet.title))
                    VStack(alignment: .leading, spacing: OmniStyle.s1) {
                        Text(snippet.title)
                        Text(snippet.abbreviation).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.Snippets.edit) { editing = snippet }.buttonStyle(.borderless)
                    Button { save(snippets.filter { $0.id != snippet.id }) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help(L10n.Snippets.delete)
                        .accessibilityLabel(L10n.Snippets.delete)
                }
            }
            if !snippets.isEmpty {
                Button(L10n.Snippets.addSnippet, action: addSnippet)
                    .settingsAnchor(SnippetsFeature.Anchor.list)
            }
            Text(L10n.Snippets.placeholdersHelp)
                .font(.caption).foregroundStyle(.secondary)
                .settingsAnchor(SnippetsFeature.Anchor.placeholders)
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
