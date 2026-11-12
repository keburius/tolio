import AppKit
import SwiftUI

struct EditorActions {
    var copy: () -> Void
    var save: () -> Void
    var pin: () -> Void
    var copyText: () -> Void
}

struct EditorView: View {
    @Bindable var model: EditorModel
    let actions: EditorActions
    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            GeometryReader { geometry in
                let k = fitScale(in: geometry.size)
                let size = CGSize(width: CGFloat(model.document.pixelWidth) * k, height: CGFloat(model.document.pixelHeight) * k)
                ZStack(alignment: .topLeading) {
                    canvas(k: k).frame(width: size.width, height: size.height)
                    if let edit = model.textEdit { textField(edit, k: k) }
                }
                .frame(width: size.width, height: size.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
        }
        .onDeleteCommand { model.deleteSelection() }
        .background(KeyShortcuts(model: model))
    }

    /// View points per image pixel: the capture at its real size, shrunk to fit.
    private func fitScale(in size: CGSize) -> CGFloat {
        let w = CGFloat(model.document.pixelWidth), h = CGFloat(model.document.pixelHeight)
        let real = 1 / model.capture.scale
        return min(real, (size.width - 24) / w, (size.height - 24) / h)
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            ForEach(EditorModel.Tool.allCases) { tool in
                Button { model.tool = tool } label: {
                    Image(systemName: tool.symbol).frame(width: 26, height: 22)
                }
                .buttonStyle(.borderless)
                .background(RoundedRectangle(cornerRadius: 6).fill(model.tool == tool ? Color.accentColor.opacity(0.25) : .clear))
                .help(tool.title)
            }
            Divider().frame(height: 20)
            ForEach(RGBAColor.palette, id: \.self) { color in
                Button { model.color = color } label: {
                    Circle().fill(Color(cgColor: color.cgColor))
                        .overlay(Circle().strokeBorder(Color.primary.opacity(model.color == color ? 0.9 : 0.25), lineWidth: model.color == color ? 2 : 1))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)
            }
            Divider().frame(height: 20)
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(.borderless).disabled(!model.canUndo).keyboardShortcut("z", modifiers: .command).help("Undo")
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(.borderless).disabled(!model.canRedo).keyboardShortcut("z", modifiers: [.command, .shift]).help("Redo")
            if model.document.crop != nil {
                Button("Reset Crop") { model.resetCrop() }.buttonStyle(.borderless)
            }
            Spacer(minLength: 12)
            Button { actions.copyText() } label: { Label("Copy Text", systemImage: "text.viewfinder") }
                .help("Recognize text in the image (on this Mac) and copy it")
            Button { actions.pin() } label: { Label("Pin", systemImage: "pin") }
                .help("Keep the image floating above other windows")
            Button { actions.copy() } label: { Label("Copy", systemImage: "doc.on.doc") }
                .keyboardShortcut("c", modifiers: .command)
            Button { actions.save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.regular)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func canvas(k: CGFloat) -> some View {
        let document = model.displayDocument
        let crop = model.document.crop
        let draftCrop = model.draftCrop
        let selection = model.selection
        let image = model.capture.image
        return Canvas { context, size in
            context.withCGContext { cg in
                cg.scaleBy(x: k, y: k)
                cg.interpolationQuality = k < 1 ? .high : .none
                AnnotationRenderer.drawImage(image, in: document.bounds, context: cg)
                AnnotationRenderer.drawAnnotations(document, base: image, in: cg)
                if let id = selection, let rect = Self.outline(of: id, in: document) {
                    cg.setStrokeColor(NSColor.controlAccentColor.cgColor)
                    cg.setLineWidth(1.5 / k)
                    cg.setLineDash(phase: 0, lengths: [4 / k, 3 / k])
                    cg.stroke(rect.insetBy(dx: -4 / k, dy: -4 / k))
                    cg.setLineDash(phase: 0, lengths: [])
                }
                if let shown = draftCrop ?? crop {
                    let path = CGMutablePath()
                    path.addRect(document.bounds)
                    path.addRect(shown)
                    cg.addPath(path)
                    cg.setFillColor(CGColor(gray: 0, alpha: 0.5))
                    cg.fillPath(using: .evenOdd)
                    cg.setStrokeColor(CGColor(gray: 1, alpha: 1))
                    cg.setLineWidth(1 / k)
                    cg.stroke(shown)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let point = CGPoint(x: value.location.x / k, y: value.location.y / k)
                    if model.isIdle {
                        model.pointerDown(point)
                    } else {
                        model.pointerDragged(point)
                    }
                }
                .onEnded { value in
                    model.pointerUp(CGPoint(x: value.location.x / k, y: value.location.y / k))
                }
        )
        .onContinuousHover { phase in
            if case .active = phase { cursor.set() }
        }
    }

    private var cursor: NSCursor {
        switch model.tool {
        case .select: .arrow
        case .text: .iBeam
        default: .crosshair
        }
    }

    private static func outline(of id: UUID, in document: AnnotationDocument) -> CGRect? {
        guard let annotation = document.annotations.first(where: { $0.id == id }) else { return nil }
        switch annotation.kind {
        case let .arrow(from, to): return Annotation.rect(from: from, to: to)
        case let .box(r), let .blur(r), let .highlight(r): return r
        case let .text(origin, string, size): return CGRect(origin: origin, size: AnnotationRenderer.textSize(string, fontSize: size))
        case let .step(center, d): return CGRect(x: center.x - d / 2, y: center.y - d / 2, width: d, height: d)
        }
    }

    private func textField(_ edit: EditorModel.TextEdit, k: CGFloat) -> some View {
        TextField("Text", text: Binding(
            get: { model.textEdit?.string ?? "" },
            set: { model.textEdit?.string = $0 }
        ))
        .textFieldStyle(.plain)
        .font(.system(size: max(9, edit.fontSize * k), weight: .semibold))
        .foregroundStyle(Color(cgColor: edit.color.cgColor))
        .frame(minWidth: 120, alignment: .leading)
        .fixedSize()
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.accentColor.opacity(0.7)))
        .offset(x: edit.origin.x * k - 2, y: edit.origin.y * k - 2)
        .focused($textFocused)
        .onAppear { textFocused = true }
        .onSubmit { model.commitText() }
        .onExitCommand { model.commitText() }
    }
}

/// Single-letter tool shortcuts, ignored while typing text.
private struct KeyShortcuts: View {
    let model: EditorModel

    var body: some View {
        ZStack {
            ForEach(EditorModel.Tool.allCases) { tool in
                Button("") { if model.textEdit == nil { model.tool = tool } }
                    .keyboardShortcut(KeyEquivalent(tool.key), modifiers: [])
                    .disabled(model.textEdit != nil)
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
    }
}
