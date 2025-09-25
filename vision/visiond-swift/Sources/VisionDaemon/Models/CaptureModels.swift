import Foundation
import CoreGraphics

struct FrameMetadata: Codable {
    let contentRectPoints: CGRect?
    let scaleFactor: CGFloat?
    let contentScale: CGFloat?
    let imageSize: CGSize?
    let perceptualHash: String?
}

struct SensorReading: Codable {
    let source: String
    let frame: CGRect?
    let text: String?
    let confidence: Double?
}

struct PaneCaptureResult {
    let paneId: String
    let timestamp: Date
    let locateLatencyMs: Int
    let captureLatencyMs: Int
    let sensors: [SensorReading]
    let image: CGImage?
    let metadata: FrameMetadata
}
