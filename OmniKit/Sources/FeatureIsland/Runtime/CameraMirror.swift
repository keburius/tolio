import AppKit
import AVFoundation
import SwiftUI

/// The front camera as a mirror. Runs only while the mirror is on screen;
/// nothing is recorded or saved.
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

    /// AVCaptureSession isn't Sendable; it's only touched on its own queue.
    final class SessionBox: @unchecked Sendable {
        let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "com.george.tolio.island.camera")
        private var configured = false

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
