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
    private let domClient = DOMBridgeClient()
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

        var domLocate: DOMLocateResponse?
        var domLocateLatency = 0
        if target.mode == .dom, let domTarget = target.dom {
            let start = Date()
            // Build a selector payload (prefer CSS locator string for now)
            var selector: [String: String] = [:]
            selector["css"] = domTarget.locator
            let req = DOMLocateRequest(app: target.app, url_contains: domTarget.urlContains, seed_url: nil, wait_until: "domcontentloaded", timeout_ms: 8000, selector: selector, scroll: true)
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    let resp = try await self.domClient.locate(req)
                    domLocate = resp
                } catch {
                    Logger.log(["stage": "locate", "source": "dom", "event": "locate_error", "error": String(describing: error)])
                }
                semaphore.signal()
            }
            semaphore.wait()
            domLocateLatency = Int(Date().timeIntervalSince(start) * 1000)
            if let resp = domLocate {
                let text = resp.inner_text
                let conf = 0.9
                sensors.append(SensorReading(source: "dom", frame: nil, text: text, confidence: conf))
                Logger.log(["stage": "locate", "source": "dom", "pane": paneId, "ok": resp.ok])
            }
        }

        if target.mode == .pixel, let pixelTarget = target.pixel {
            let rect = CGRect(x: pixelTarget.roi.x, y: pixelTarget.roi.y, width: pixelTarget.roi.w, height: pixelTarget.roi.h)
            sensors.append(SensorReading(source: "pixel", frame: rect, text: nil, confidence: nil))
        }
        var locateLatency = Int(Date().timeIntervalSince(locateStart) * 1000)
        if domLocateLatency > 0 { locateLatency = domLocateLatency }
        let captureStart = Date()
        let (image, attachments, mapCropMs) = captureImage(for: target, sensors: sensors, domLocate: domLocate)
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
            mapCropLatencyMs: mapCropMs,
            sensors: sensors,
            image: image,
            metadata: metadata
        )
    }

    private func captureImage(for target: TargetEntry, sensors: [SensorReading], domLocate: DOMLocateResponse?) -> (CGImage?, FrameAttachments?, Int?) {
        guard let window = shareableContentCache.window(for: target.app) else {
            Logger.log(["stage": "capture", "event": "window_not_found", "app": target.app])
            return (nil, nil, nil)
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: Int32(max(1, config.stream.defaultFps)))

        var capturedImage: CGImage?
        var attachments: FrameAttachments?
        var mapCropLatencyMs: Int?
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
                if target.mode == .dom, let attachments, let domLocate, domLocate.ok, let bbox = domLocate.bbox, let viewport = domLocate.viewport {
                    let startMap = Date()
                    let inset: ViewportPixelInset
                    if let off = target.pixelOffset { inset = ViewportPixelInset(dx: CGFloat(off.dx), dy: CGFloat(off.dy), dw: CGFloat(off.w), dh: CGFloat(off.h)) } else { inset = .zero }
                    do {
                        let rect = try mapDOMBBoxToPixelCrop(domBBox: bbox, viewport: viewport, attachments: attachments, inset: inset)
                        capturedImage = image.cropping(to: rect)
                    } catch {
                        // Fall back to geometry-based mapping if any error
                        if let roi = self.geometry.resolveROI(target: target, sensors: sensors, attachments: attachments, image: image) {
                            capturedImage = image.cropping(to: roi)
                        }
                    }
                    mapCropLatencyMs = Int(Date().timeIntervalSince(startMap) * 1000)
                } else if let attachments, let roi = self.geometry.resolveROI(target: target, sensors: sensors, attachments: attachments, image: image) {
                    capturedImage = image.cropping(to: roi)
                }
            }
        }

        semaphore.wait()
        return (capturedImage, attachments, mapCropLatencyMs)
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
