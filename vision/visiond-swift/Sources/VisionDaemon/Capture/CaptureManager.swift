import Foundation
import AppKit
import ScreenCaptureKit
import VideoToolbox
import CoreMedia

@available(macOS 14.0, *)
final class CaptureManager {
    private let targets: TargetsConfig
    private let config: VisiondConfig
    private let axResolver = AXResolver()
    private let domBridge = DOMBridge()
    private let frameHasher: FrameHasher
    private let geometry = GeometryMapper()
    private let shareableContentCache = ShareableContentCache()

    init(targets: TargetsConfig, config: VisiondConfig) {
        self.targets = targets
        self.config = config
        self.frameHasher = FrameHasher(config: config.hashing)
    }

    func captureOnce(paneId: String) -> PaneCaptureResult? {
        guard let target = targets.panes[paneId] else { return nil }
        let locateStart = Date()
        var sensors: [SensorReading] = []
        if target.mode == .ax, let axTarget = target.ax {
            if let reading = axResolver.resolve(appBundleId: target.app, target: axTarget) {
                sensors.append(reading)
                Logger.log(["stage": "locate", "source": "ax", "pane": paneId, "confidence": reading.confidence ?? 0.0])
            }
        }

        if target.mode == .dom, let domTarget = target.dom {
            if let reading = domBridge.resolve(appBundleId: target.app, target: domTarget) {
                sensors.append(reading)
                Logger.log(["stage": "locate", "source": "dom", "pane": paneId, "confidence": reading.confidence ?? 0.0])
            }
        }

        if target.mode == .pixel, let pixelTarget = target.pixel {
            let rect = CGRect(x: pixelTarget.roi.x, y: pixelTarget.roi.y, width: pixelTarget.roi.w, height: pixelTarget.roi.h)
            sensors.append(SensorReading(source: "pixel", frame: rect, text: nil, confidence: nil))
        }
        let locateLatency = Int(Date().timeIntervalSince(locateStart) * 1000)
        let captureStart = Date()
        let (image, attachments) = captureImage(for: target, sensors: sensors)
        let captureLatency = Int(Date().timeIntervalSince(captureStart) * 1000)
        let timestamp = Date()
        let metadata = FrameMetadata(
            contentRectPoints: attachments?.contentRectPoints,
            scaleFactor: attachments?.scaleFactor,
            contentScale: attachments?.contentScale,
            imageSize: image.map { CGSize(width: $0.width, height: $0.height) },
            perceptualHash: image.flatMap { frameHasher.hash(image: $0) }
        )

        return PaneCaptureResult(
            paneId: paneId,
            timestamp: timestamp,
            locateLatencyMs: locateLatency,
            captureLatencyMs: captureLatency,
            sensors: sensors,
            image: image,
            metadata: metadata
        )
    }

    private func captureImage(for target: TargetEntry, sensors: [SensorReading]) -> (CGImage?, FrameAttachments?) {
        guard let window = shareableContentCache.window(for: target.app) else {
            Logger.log(["stage": "capture", "event": "window_not_found", "app": target.app])
            return (nil, nil)
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: Int32(max(1, config.stream.defaultFps)))

        var capturedImage: CGImage?
        var attachments: FrameAttachments?
        let semaphore = DispatchSemaphore(value: 0)

        SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration: configuration) { sampleBuffer, error in
            defer { semaphore.signal() }
            guard error == nil, let buffer = sampleBuffer else {
                if let error = error {
                    Logger.log(["stage": "capture", "event": "screenshot_error", "error": String(describing: error)])
                }
                return
            }
            capturedImage = Self.makeImage(from: buffer)
            if let att = try? readFrameAttachments(from: buffer) {
                attachments = att
            }

            if let image = capturedImage {
                if let attachments, let roi = self.geometry.resolveROI(target: target, sensors: sensors, attachments: attachments, image: image) {
                    capturedImage = image.cropping(to: roi)
                }
            }
        }

        semaphore.wait()
        return (capturedImage, attachments)
    }

    private static func makeImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        return image
    }
}

@available(macOS 13.0, *)
final class ShareableContentCache {
    private var lastFetch: Date = .distantPast
    private var windows: [SCWindow] = []
    private let lock = NSLock()

    func window(for bundleIdentifier: String) -> SCWindow? {
        refreshIfNeeded()
        return windows.first { $0.owningApplication?.bundleIdentifier == bundleIdentifier }
    }

    private func refreshIfNeeded() {
        lock.lock(); defer { lock.unlock() }
        if Date().timeIntervalSince(lastFetch) < 1.5 { return }
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            if let content = try? await SCShareableContent.current {
                self.windows = content.windows
            }
            self.lastFetch = Date()
            semaphore.signal()
        }
        semaphore.wait()
    }
}

@available(macOS 13.0, *)
final class FrameHasher {
    private let config: VisiondConfig.HashingSettings

    init(config: VisiondConfig.HashingSettings) {
        self.config = config
    }

    func hash(image: CGImage) -> String? {
        guard config.enabled else { return nil }
        switch config.mode.lowercased() {
        case "dhash":
            return PerceptualHash.dHashHex(image)
        case "phash":
            return PerceptualHash.dHashHex(image) // TODO: implement pHash variant
        default:
            return nil
        }
    }
}
