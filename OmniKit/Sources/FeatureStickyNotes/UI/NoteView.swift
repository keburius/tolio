import AppKit
import OmniCore
import OmniPlatform
import SwiftUI

extension NoteTint {
    var color: Color {
        switch self {
        case .yellow: Color(red: 1, green: 0.84, blue: 0.2)
        case .orange: Color(red: 1, green: 0.6, blue: 0.2)
        case .pink: Color(red: 1, green: 0.45, blue: 0.65)
        case .purple: Color(red: 0.68, green: 0.48, blue: 1)
        case .blue: Color(red: 0.3, green: 0.6, blue: 1)
        case .green: Color(red: 0.35, green: 0.85, blue: 0.45)
        case .gray: Color(white: 0.6)
        }
    }

    var name: String {
        switch self {
        case .yellow: L10n.StickyNotes.tintYellow
        case .orange: L10n.StickyNotes.tintOrange
        case .pink: L10n.StickyNotes.tintPink
        case .purple: L10n.StickyNotes.tintPurple
        case .blue: L10n.StickyNotes.tintBlue
        case .green: L10n.StickyNotes.tintGreen
        case .gray: L10n.StickyNotes.tintGray
        }
    }
}

/// A glass note: a slim header (shown on hover) and the text.
struct NoteView: View {
    @Bindable var model: NoteModel
    let actions: NoteActions
    @State private var hovering = false
    @FocusState private var focused: Bool
    static let radius: CGFloat = 18

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .topLeading) {
                if model.note.text.isEmpty {
                    Text(L10n.StickyNotes.placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 17)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $model.text)
                    .font(.system(size: 15))
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .focused($focused)
            }
        }
        .frame(minWidth: StickyNote.minimumSize.width, minHeight: StickyNote.minimumSize.height)
        .modifier(GlassBackground(tint: model.note.tint.color))
        .onHover { hovering = $0 }
        .onAppear { if model.note.text.isEmpty { focused = true } }
    }

    private var header: some View {
        HStack(spacing: OmniStyle.s2) {
            MoveHandle().frame(maxWidth: .infinity, maxHeight: .infinity)
            if hovering || focused {
                Menu {
                    ForEach(NoteTint.allCases, id: \.self) { tint in
                        Button { actions.setTint(model.note.id, tint) } label: {
                            if tint == model.note.tint { Label(tint.name, systemImage: "checkmark") } else { Text(tint.name) }
                        }
                    }
                    Divider()
                    Toggle(L10n.StickyNotes.keepOnTop, isOn: Binding(
                        get: { model.note.keepOnTop },
                        set: { actions.setKeepOnTop(model.note.id, $0) }
                    ))
                } label: {
                    Image(systemName: "paintpalette")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(L10n.StickyNotes.colorAndOptions)
                headerButton("plus", L10n.StickyNotes.newNote, actions.newNote)
                headerButton("trash", L10n.StickyNotes.deleteNote) { actions.delete(model.note.id) }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .foregroundStyle(.secondary)
    }

    private func headerButton(_ symbol: String, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 18, height: 18) }
            .buttonStyle(.borderless)
            .help(title)
            .accessibilityLabel(title)
    }
}

/// Liquid Glass on macOS 26 and later, frosted material before that.
private struct GlassBackground: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: NoteView.radius, style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint.opacity(0.35)), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(OmniStyle.increaseContrast ? 0.6 : 0.15)))
        } else {
            content
                .background(shape.fill(.thinMaterial))
                .background(shape.fill(tint.opacity(0.35)))
                .clipShape(shape)
                .overlay(shape.strokeBorder(.white.opacity(OmniStyle.increaseContrast ? 0.6 : 0.15)))
        }
    }
}

/// Dragging here moves the note (the text area keeps drags for selecting text).
private struct MoveHandle: NSViewRepresentable {
    final class HandleView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    }

    func makeNSView(context: Context) -> NSView { HandleView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
