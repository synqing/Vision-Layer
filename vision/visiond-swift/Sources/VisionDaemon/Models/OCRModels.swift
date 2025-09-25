import Foundation
import CoreGraphics

struct OCRToken: Codable {
    let text: String
    let bbox: [Double] // x,y,w,h normalized 0..1 within ROI
    let confidence: Double

    var json: [String: Any] {
        ["text": text, "bbox": bbox, "confidence": confidence]
    }
}

extension CGImage {
    func cropped(to rect: CGRect) -> CGImage? {
        return self.cropping(to: rect)
    }
}

