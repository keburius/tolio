import AppKit
import AVFoundation
import OmniCore
import SwiftUI

/// The front camera as a mirror. Runs only while the mirror is on screen;
/// nothing is recorded, and a photo is saved only when you take one.
@MainActor
@Observable
final class CameraMirror {
    enum Access { case allowed, denied, notAsked, noCamera }

    private(set) var access: Access = .notAsked
    private(set) var running = false
    @ObservationIgnored let session = SessionBox()

    init() { refreshAccess() }

    func refreshAccess() {
        guard AVCaptureDevice.default(for: .video) != nil else { access = .noCamera; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: access = .allowed
        case .notDetermined: access = .notAsked
        default: access = .denied
        }
    }

    func requestAccess() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        refreshAccess()
    }

    func start() {
        refreshAccess()
        guard access == .allowed, !running else { return }
        running = true
        session.start()
    }

    func stop() {
        guard running else { return }
        running = false
        session.stop()
    }

    /// Takes a photo, mirrored like the preview, saves it as a JPEG in
    /// Pictures › All Set and copies it. Returns the file, or nil.
    func takePhoto() async -> URL? {
        guard running else { return nil }
        guard let data = await session.capture(), let image = NSImage(data: data),
              let jpeg = Self.mirroredJPEG(image) else { return nil }
        guard let folder = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("All Set", isDirectory: true) else { return nil } // l10n-ignore
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss" // l10n-ignore
        let stamp = formatter.string(from: Date())
        var url = folder.appendingPathComponent(L10n.Island.photoFileName(stamp)).appendingPathExtension("jpg")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(L10n.Island.photoFileName(stamp)) \(n)").appendingPathExtension("jpg") // l10n-ignore
            n += 1
        }
        do { try jpeg.write(to: url) } catch { return nil }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL, NSImage(data: jpeg) ?? image])
        return url
    }

    /// The photo flipped left to right, as JPEG.
    private static func mirroredJPEG(_ image: NSImage) -> Data? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = cg.width, height = cg.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: CGFloat(width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let flipped = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: flipped).representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }

    /// AVCaptureSession isn't Sendable; it's only touched on its own queue.
    final class SessionBox: @unchecked Sendable {
        let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "com.george.tolio.island.camera")
        private var configured = false
        private let photoOutput = AVCapturePhotoOutput()
        /// Delegates of photos being taken (the output doesn't keep them).
        private var pending: [PhotoDelegate] = []

        func start() {
            queue.async { [self] in
                if !configured {
                    configured = true
                    session.beginConfiguration()
                    session.sessionPreset = .medium
                    if let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device),
                       session.canAddInput(input) {
                        session.addInput(input)
                    }
                    if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
                    session.commitConfiguration()
                }
                if !session.isRunning { session.startRunning() }
            }
        }

        func stop() {
            queue.async { [self] in
                if session.isRunning { session.stopRunning() }
            }
        }

        /// One photo from the running session, as image data.
        func capture() async -> Data? {
            await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                queue.async { [self] in
                    guard session.isRunning, session.outputs.contains(photoOutput) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let delegate = PhotoDelegate()
                    delegate.done = { [self] finished, data in
                        continuation.resume(returning: data)
                        queue.async { self.pending.removeAll { $0 === finished } }
                    }
                    pending.append(delegate)
                    photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
                }
            }
        }
    }

    final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
        /// Called once with this delegate and the photo's data (nil on failure).
        var done: (@Sendable (PhotoDelegate, Data?) -> Void)?

        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            done?(self, error == nil ? photo.fileDataRepresentation() : nil)
            done = nil
        }
    }
}

/// Shows the camera, flipped like a mirror.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        view.layer = layer
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
