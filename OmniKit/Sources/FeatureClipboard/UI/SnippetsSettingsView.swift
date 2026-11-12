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
            ForEach(snippets) { snippet in
                HStack {
                    Toggle("", isOn: Binding(
                        get: { snippet.isEnabled },
                        set: { enabled in update(snippet.id) { $0.isEnabled = enabled } }
                    ))
                    .labelsHidden()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snippet.title)
                        Text(snippet.abbreviation).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { editing = snippet }.buttonStyle(.borderless)
                    Button { save(snippets.filter { $0.id != snippet.id }) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help("Delete")
                }
            }
            Button("Add Snippet") {
                editing = Snippet(abbreviation: "", title: "", body: "")
            }
            Text("Placeholders: {date}, {date:yyyy-MM-dd}, {time}, {time:HH:mm}, {clipboard}, {cursor}. Use {{ and }} for literal braces. Snippets never expand in password fields.")
                .font(.caption).foregroundStyle(.secondary)
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
            TextField("Abbreviation", text: $snippet.abbreviation, prompt: Text(";sig"))
            if let problem, !snippet.abbreviation.isEmpty {
                Text(problem).font(.caption).foregroundStyle(.red)
            }
            TextField("Title", text: $snippet.title)
            TextEditor(text: $snippet.body)
                .font(.body.monospaced())
                .frame(minHeight: 140)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if snippet.title.isEmpty { snippet.title = snippet.abbreviation }
                    onSave(snippet)
                }
                .disabled(problem != nil || snippet.body.isEmpty)
            }
        }
    }
}
