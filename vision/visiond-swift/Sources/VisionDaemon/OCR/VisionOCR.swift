import Foundation
import Vision
import CoreGraphics

final class VisionOCR {
    private let languages: [String]
    private let minTextHeight: Double
    init(languages: [String], minTextHeight: Double) {
        self.languages = languages
        self.minTextHeight = minTextHeight
    }

    func recognize(image: CGImage) -> [OCRToken] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages
        if #available(macOS 12.0, *) {
            request.minimumTextHeight = Float(minTextHeight)
        }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return [] }
            var tokens: [OCRToken] = []
            for obs in observations {
                guard let cand = obs.topCandidates(1).first else { continue }
                let bbox = [Double(obs.boundingBox.origin.x), Double(obs.boundingBox.origin.y), Double(obs.boundingBox.size.width), Double(obs.boundingBox.size.height)]
                let conf = cand.confidence.isNaN ? 0.0 : Double(cand.confidence)
                tokens.append(OCRToken(text: cand.string, bbox: bbox, confidence: conf))
            }
            return tokens
        } catch {
            return []
        }
    }
}
