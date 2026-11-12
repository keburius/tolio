import CoreGraphics
import Vision

/// On-device OCR and barcode reading with Vision. Nothing leaves the Mac.
public enum TextRecognizer {
    public struct Options: Equatable, Sendable {
        /// Vision language codes in priority order; empty = Vision's default.
        public var languages: [String]
        public var automaticLanguageDetection: Bool

        public init(languages: [String] = [], automaticLanguageDetection: Bool = true) {
            self.languages = languages
            self.automaticLanguageDetection = automaticLanguageDetection
        }
    }

    public struct Result: Sendable {
        public var lines: [String]
        /// QR code and barcode contents.
        public var codes: [String]
    }

    /// Languages Vision can read on this Mac (accurate level).
    public static func supportedLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? []
    }

    /// Recognized lines (top to bottom, left to right) and any codes.
    public static func recognize(in image: CGImage, options: Options = Options(), barcodes: Bool = true) async throws -> Result {
        try await Task.detached(priority: .userInitiated) {
            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .accurate
            text.usesLanguageCorrection = true
            text.automaticallyDetectsLanguage = options.automaticLanguageDetection
            if !options.languages.isEmpty { text.recognitionLanguages = options.languages }
            var requests: [VNRequest] = [text]
            let codes = VNDetectBarcodesRequest()
            if barcodes { requests.append(codes) }
            try VNImageRequestHandler(cgImage: image, options: [:]).perform(requests)
            // Vision's boxes are normalized with a bottom-left origin.
            let sorted = (text.results ?? []).sorted { a, b in
                let ay = a.boundingBox.midY, by = b.boundingBox.midY
                if abs(ay - by) > min(a.boundingBox.height, b.boundingBox.height) / 2 { return ay > by }
                return a.boundingBox.minX < b.boundingBox.minX
            }
            var seen = Set<String>()
            let payloads = (barcodes ? codes.results ?? [] : []).compactMap(\.payloadStringValue).filter { seen.insert($0).inserted }
            return Result(lines: sorted.compactMap { $0.topCandidates(1).first?.string }, codes: payloads)
        }.value
    }

    /// Lines only, with automatic language detection (the editor's Copy Text).
    public static func lines(in image: CGImage) async throws -> [String] {
        try await recognize(in: image, barcodes: false).lines
    }
}
