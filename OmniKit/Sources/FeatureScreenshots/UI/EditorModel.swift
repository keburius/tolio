import AppKit
import Observation
import OmniCore

/// State of one editor window. All geometry is in image pixels (top-left origin).
@MainActor
@Observable
final class EditorModel {
    enum Tool: String, CaseIterable, Identifiable {
        case select, brush, arrow, box, text, highlight, blur, step, crop
        var id: String { rawValue }

        var title: String {
            switch self {
            case .select: L10n.Screenshots.toolSelect
            case .brush: L10n.Screenshots.toolBrush
            case .arrow: L10n.Screenshots.toolArrow
            case .box: L10n.Screenshots.toolBox
            case .text: L10n.Screenshots.toolText
            case .highlight: L10n.Screenshots.toolHighlight
            case .blur: L10n.Screenshots.toolBlur
            case .step: L10n.Screenshots.toolStep
            case .crop: L10n.Screenshots.toolCrop
            }
        }

        var symbol: String {
            switch self {
            case .select: "cursorarrow"
            case .brush: "scribble.variable"
            case .arrow: "arrow.up.right"
            case .box: "rectangle"
            case .text: "textformat"
            case .highlight: "highlighter"
            case .blur: "drop.halffull"
            case .step: "1.circle"
            case .crop: "crop"
            }
        }

        var key: Character {
            switch self {
            case .select: "v"
            case .brush: "p"
            case .arrow: "a"
            case .box: "r"
            case .text: "t"
            case .highlight: "h"
            case .blur: "b"
            case .step: "n"
            case .crop: "c"
            }
        }
    }

    struct TextEdit: Equatable {
        /// Existing annotation being edited, or nil for a new one.
        var id: UUID?
        var origin: CGPoint
        var string: String
        var fontSize: CGFloat
        var color: RGBAColor
    }

    let capture: Capture
    private(set) var document: AnnotationDocument
    var tool: Tool = .brush {
        didSet {
            commitText()
            if tool == .highlight && color == .red { color = .yellow }
            if oldValue == .highlight && tool != .highlight && color == .yellow { color = .red }
        }
    }
    var color: RGBAColor = .red {
        didSet { recolorSelection() }
    }
    var selection: UUID?
    var textEdit: TextEdit?
    /// The mark being drawn, shown but not yet in the document.
    private(set) var draft: Annotation?
    private(set) var draftCrop: CGRect?
    private var undoStack: [AnnotationDocument] = []
    private var redoStack: [AnnotationDocument] = []
    private var dragStart: CGPoint?
    private var lastDrag: CGPoint?
    private var movedDuringDrag = false

    init(capture: Capture) {
        self.capture = capture
        document = AnnotationDocument(pixelWidth: capture.image.width, pixelHeight: capture.image.height, scale: capture.scale)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    /// No pointer gesture in progress.
    var isIdle: Bool { dragStart == nil }
    var canRedo: Bool { !redoStack.isEmpty }

    /// The document as drawn on screen, including the mark in progress.
    var displayDocument: AnnotationDocument {
        var doc = document
        if let draft { doc.add(draft) }
        return doc
    }

    // MARK: - Editing

    private func change(_ body: (inout AnnotationDocument) -> Void) {
        var copy = document
        body(&copy)
        guard copy != document else { return }
        undoStack.append(document)
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
        document = copy
    }

    func undo() {
        commitText()
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(document)
        document = previous
        selection = nil
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
    }

    /// Something Delete can remove: the selected mark, else the newest one.
    var canDelete: Bool { selection != nil || !document.annotations.isEmpty }

    /// Deletes the selected mark, or the newest mark when nothing is
    /// selected (so it works right after drawing, like an eraser for the last stroke).
    func deleteSelection() {
        commitText()
        guard let id = selection ?? document.annotations.last?.id else { return }
        change { $0.remove(id) }
        selection = nil
    }

    func resetCrop() {
        change { $0.setCrop(nil) }
    }

    private func recolorSelection() {
        guard let id = selection, var annotation = document.annotations.first(where: { $0.id == id }), annotation.color != color else { return }
        annotation.color = color
        change { $0.replace(annotation) }
    }

    // MARK: - Pointer

    func pointerDown(_ p: CGPoint) {
        let point = clamp(p)
        dragStart = point
        lastDrag = point
        movedDuringDrag = false
        let lineWidth = document.defaultLineWidth
        switch tool {
        case .select:
            commitText()
            selection = document.hitTest(point, tolerance: 6 * document.scale) { AnnotationRenderer.textSize($0, fontSize: $1) }
        case .brush:
            draft = Annotation(kind: .stroke([point]), color: color, lineWidth: lineWidth * 1.4)
        case .arrow:
            draft = Annotation(kind: .arrow(from: point, to: point), color: color, lineWidth: lineWidth)
        case .box:
            draft = Annotation(kind: .box(CGRect(origin: point, size: .zero)), color: color, lineWidth: lineWidth)
        case .highlight:
            draft = Annotation(kind: .highlight(CGRect(origin: point, size: .zero)), color: color, lineWidth: 0)
        case .blur:
            draft = Annotation(kind: .blur(CGRect(origin: point, size: .zero)), color: color, lineWidth: 0)
        case .step:
            let annotation = Annotation(kind: .step(center: point, diameter: document.defaultStepDiameter), color: color, lineWidth: lineWidth)
            change { $0.add(annotation) }
        case .text:
            commitText()
            // Clicking an existing text edits it.
            if let id = document.hitTest(point, tolerance: 4, textSize: { AnnotationRenderer.textSize($0, fontSize: $1) }),
               let annotation = document.annotations.first(where: { $0.id == id }),
               case let .text(origin, string, size) = annotation.kind {
                textEdit = TextEdit(id: id, origin: origin, string: string, fontSize: size, color: annotation.color)
            } else {
                textEdit = TextEdit(id: nil, origin: point, string: "", fontSize: document.defaultFontSize, color: color)
            }
        case .crop:
            draftCrop = CGRect(origin: point, size: .zero)
        }
    }

    func pointerDragged(_ p: CGPoint) {
        let point = clamp(p)
        guard let start = dragStart else { return }
        switch tool {
        case .select:
            guard let id = selection, let last = lastDrag else { return }
            let delta = CGVector(dx: point.x - last.x, dy: point.y - last.y)
            if !movedDuringDrag {
                undoStack.append(document) // one undo step for the whole move
                redoStack.removeAll()
                movedDuringDrag = true
            }
            document.move(id, by: delta)
        case .brush:
            // Skip points closer than a pixel; they add size, not detail.
            if case var .stroke(points) = draft?.kind, let last = points.last, hypot(point.x - last.x, point.y - last.y) >= 1 {
                points.append(point)
                draft?.kind = .stroke(points)
            }
        case .arrow:
            draft?.kind = .arrow(from: start, to: point)
        case .box:
            draft?.kind = .box(Annotation.rect(from: start, to: point))
        case .highlight:
            draft?.kind = .highlight(Annotation.rect(from: start, to: point))
        case .blur:
            draft?.kind = .blur(Annotation.rect(from: start, to: point))
        case .crop:
            draftCrop = Annotation.rect(from: start, to: point)
        case .step, .text:
            break
        }
        lastDrag = point
    }

    func pointerUp(_ p: CGPoint) {
        pointerDragged(p)
        if let draft {
            let finished = draft
            self.draft = nil
            change { $0.add(finished) }
            // Shapes stay selected so Delete or a color change applies to them;
            // brush strokes don't, so drawing isn't interrupted by outlines.
            if !finished.isDegenerate, !finished.isStroke { selection = finished.id }
        }
        if let crop = draftCrop {
            draftCrop = nil
            if crop.width >= 4 && crop.height >= 4 { change { $0.setCrop(crop) } }
        }
        dragStart = nil
        lastDrag = nil
    }

    func commitText() {
        guard let edit = textEdit else { return }
        textEdit = nil
        let annotation = Annotation(
            id: edit.id ?? UUID(), kind: .text(origin: edit.origin, string: edit.string, fontSize: edit.fontSize),
            color: edit.color, lineWidth: 0
        )
        if edit.id != nil {
            change { $0.replace(annotation) }
        } else {
            change { $0.add(annotation) }
        }
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), CGFloat(document.pixelWidth)), y: min(max(p.y, 0), CGFloat(document.pixelHeight)))
    }

    /// The image to copy, save, or pin.
    func export() -> CGImage? {
        commitText()
        return AnnotationRenderer.render(document, base: capture.image)
    }
}
