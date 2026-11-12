import AppKit
import Observation
import SwiftUI
import Translation

@MainActor
@Observable
final class PopupModel {
    var actions: [ActionItem] = []
    var hovering = false
    var translationText: String?
    var translationReplaceable = false
    @ObservationIgnored var onPerform: (String) -> Void = { _ in }
    @ObservationIgnored var onReplace: (String) -> Void = { _ in }
    @ObservationIgnored var onTranslationClosed: () -> Void = {}

    struct ActionItem: Identifiable, Equatable {
        let id: String
        let title: String
        let symbolName: String
    }
}

struct PopupView: View {
    @Bindable var model: PopupModel
    static let height: CGFloat = 34
    static let buttonWidth: CGFloat = 32

    var body: some View {
        HStack(spacing: 2) {
            ForEach(model.actions) { action in
                Button { model.onPerform(action.id) } label: {
                    Image(systemName: action.symbolName)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: Self.buttonWidth, height: Self.height - 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PopupButtonStyle())
                .help(action.title)
                .accessibilityLabel(action.title)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: Self.height)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.12)))
        .onHover { model.hovering = $0 }
        .modifier(TranslationModifier(model: model))
    }

    static func width(for count: Int) -> CGFloat { CGFloat(count) * (buttonWidth + 2) + 8 }
}

private struct PopupButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(configuration.isPressed ? 0.2 : 0.0001)))
            .modifier(HoverHighlight())
    }
}

private struct HoverHighlight: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(hovering ? 0.1 : 0)))
            .onHover { hovering = $0 }
    }
}

/// Apple's translation panel (the same one as "Translate" in context menus).
private struct TranslationModifier: ViewModifier {
    @Bindable var model: PopupModel

    func body(content: Content) -> some View {
        if #available(macOS 14.4, *) {
            content.translationPresentation(
                isPresented: Binding(
                    get: { model.translationText != nil },
                    set: { if !$0 { model.translationText = nil; model.onTranslationClosed() } }
                ),
                text: model.translationText ?? "",
                arrowEdge: .bottom,
                replacementAction: model.translationReplaceable ? { model.onReplace($0) } : nil
            )
        } else {
            content
        }
    }
}
