import CoreGraphics
import Vision

/// On-device OCR with Vision. Nothing leaves the Mac.
public enum TextRecognizer {
    /// Recognized lines, top to bottom, left to right.
    public static func lines(in image: CGImage) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            let observations = request.results ?? []
            // Vision's boxes are normalized with a bottom-left origin.
            let sorted = observations.sorted { a, b in
                let ay = a.boundingBox.midY, by = b.boundingBox.midY
                if abs(ay - by) > min(a.boundingBox.height, b.boundingBox.height) / 2 { return ay > by }
                return a.boundingBox.minX < b.boundingBox.minX
            }
            return sorted.compactMap { $0.topCandidates(1).first?.string }
        }.value
    }
}
