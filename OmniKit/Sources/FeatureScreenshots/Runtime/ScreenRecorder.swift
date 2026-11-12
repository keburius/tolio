import AVFoundation
import OmniCore
@preconcurrency import ScreenCaptureKit

public enum VideoCodec: String, Codable, CaseIterable, Sendable {
    case h264, hevc
    var label: String { self == .h264 ? L10n.Screenshots.codecH264 : L10n.Screenshots.codecHEVC }
    var avCodec: AVVideoCodecType { self == .h264 ? .h264 : .hevc }
}

struct RecordingOptions: Sendable {
    var framesPerSecond = 30
    var codec: VideoCodec = .h264
    var systemAudio = false
    /// macOS 15+ (ScreenCaptureKit microphone capture).
    var microphone = false
    var showsCursor = true
}

/// Records one display area to an MP4 file: ScreenCaptureKit stream →
/// AVAssetWriter. System audio and the microphone go to separate AAC tracks.
/// All sample handling happens on one serial queue.
final class ScreenRecorder: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let url: URL
    private let queue = DispatchQueue(label: "com.george.omni.recorder")
    private var stream: SCStream?
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private var audioInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var stopped = false
    private var clock = PauseClock()
    private var micMuted = false
    private var failure: Error?
    private let log = Log.logger("recorder")
    /// Called on the main actor if the stream stops by itself (display gone, permission revoked).
    var onUnexpectedStop: (@MainActor (Error) -> Void)?

    init(url: URL, pixelWidth: Int, pixelHeight: Int, options: RecordingOptions) throws {
        self.url = url
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let bitsPerSecond = Double(pixelWidth * pixelHeight * options.framesPerSecond) * (options.codec == .hevc ? 0.08 : 0.12)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: options.codec.avCodec,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(min(bitsPerSecond, 80_000_000)),
                AVVideoExpectedSourceFrameRateKey: options.framesPerSecond,
                AVVideoMaxKeyFrameIntervalKey: options.framesPerSecond * 2,
            ] as [String: Any],
        ])
        videoInput.expectsMediaDataInRealTime = true
        super.init()
        guard writer.canAdd(videoInput) else { throw CaptureError.failed(L10n.Screenshots.errorEncoderSize(pixelWidth, pixelHeight)) }
        writer.add(videoInput)
        if options.systemAudio {
            let input = Self.audioInput(channels: 2)
            if writer.canAdd(input) { writer.add(input); audioInput = input }
        }
        if options.microphone {
            let input = Self.audioInput(channels: 1)
            if writer.canAdd(input) { writer.add(input); micInput = input }
        }
    }

    private static func audioInput(channels: Int) -> AVAssetWriterInput {
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: channels == 1 ? 96_000 : 160_000,
        ])
        input.expectsMediaDataInRealTime = true
        return input
    }

    func start(filter: SCContentFilter, sourceRect: CGRect?, pixelWidth: Int, pixelHeight: Int, options: RecordingOptions) async throws {
        let configuration = SCStreamConfiguration()
        configuration.width = pixelWidth
        configuration.height = pixelHeight
        if let sourceRect { configuration.sourceRect = sourceRect }
        configuration.scalesToFit = false
        configuration.captureResolution = .best
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(options.framesPerSecond))
        configuration.queueDepth = 6
        configuration.showsCursor = options.showsCursor
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        if options.systemAudio {
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 48_000
            configuration.channelCount = 2
        }
        if options.microphone, #available(macOS 15.0, *) {
            configuration.captureMicrophone = true
        }
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        if options.systemAudio { try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue) }
        if options.microphone, #available(macOS 15.0, *) {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        }
        guard writer.startWriting() else { throw writer.error ?? CaptureError.failed(L10n.Screenshots.errorStartFile) }
        self.stream = stream
        try await stream.startCapture()
    }

    /// Stops and finishes the file. Returns the file URL, or throws if nothing usable was written.
    func stop() async throws -> URL {
        if let stream { try? await stream.stopCapture() }
        stream = nil
        let started: Bool = queue.sync {
            stopped = true
            return sessionStarted
        }
        guard started else {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            throw failure ?? CaptureError.failed(L10n.Screenshots.errorNoFrames)
        }
        queue.sync {
            videoInput.markAsFinished()
            audioInput?.markAsFinished()
            micInput?.markAsFinished()
        }
        await writer.finishWriting()
        if writer.status != .completed { throw writer.error ?? CaptureError.failed(L10n.Screenshots.errorFinishFile) }
        return url
    }

    // MARK: - Pause and mute

    func pause() { queue.async { self.clock.pause() } }
    func resume() { queue.async { self.clock.resume() } }
    /// Drops microphone audio while muted (the track just has silence there).
    func setMicMuted(_ muted: Bool) { queue.async { self.micMuted = muted } }

    /// The buffer moved earlier by the paused time, or nil while paused.
    private func retimed(_ buffer: CMSampleBuffer) -> CMSampleBuffer? {
        let pts = buffer.presentationTimeStamp
        guard let adjusted = clock.adjust(pts.seconds) else { return nil }
        guard clock.offset > 0 else { return buffer }
        var timing = CMSampleTimingInfo(
            duration: buffer.duration,
            presentationTimeStamp: CMTime(seconds: adjusted, preferredTimescale: pts.timescale),
            decodeTimeStamp: .invalid
        )
        var copy: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault, sampleBuffer: buffer, sampleTimingEntryCount: 1,
            sampleTimingArray: &timing, sampleBufferOut: &copy
        ) == noErr else { return nil }
        return copy
    }

    // MARK: - SCStreamOutput (on `queue`)

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !stopped, sampleBuffer.isValid, writer.status == .writing else { return }
        switch type {
        case .screen:
            // Only complete frames carry an image; idle/blank ones are skipped.
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let rawStatus = attachments.first?[.status] as? Int,
                  SCFrameStatus(rawValue: rawStatus) == .complete else { return }
            guard let buffer = retimed(sampleBuffer) else { return }
            if !sessionStarted {
                writer.startSession(atSourceTime: buffer.presentationTimeStamp)
                sessionStarted = true
            }
            if videoInput.isReadyForMoreMediaData { videoInput.append(buffer) }
        case .audio:
            guard sessionStarted, let audioInput, audioInput.isReadyForMoreMediaData, let buffer = retimed(sampleBuffer) else { return }
            audioInput.append(buffer)
        default:
            if #available(macOS 15.0, *), type == .microphone {
                guard sessionStarted, !micMuted, let micInput, micInput.isReadyForMoreMediaData, let buffer = retimed(sampleBuffer) else { return }
                micInput.append(buffer)
            }
        }
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log.error("Recording stream stopped: \(error.localizedDescription, privacy: .public)")
        queue.async { self.failure = error }
        let callback = onUnexpectedStop
        Task { @MainActor in callback?(error) }
    }
}
