import Foundation
import CoreGraphics
import NIO
import NIOHTTP1

@main
struct Main {
    static func main() throws {
        guard #available(macOS 14.0, *) else {
            fatalError("ScreenCaptureKit SCScreenshotManager requires macOS 14.0 or newer")
        }

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let configDir = root.appendingPathComponent("vision").appendingPathComponent("config")
        let shared = AppSharedState(configDir: configDir)
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        defer { try? group.syncShutdownGracefully() }

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(HTTPHandler(shared: shared))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        let channel = try bootstrap.bind(host: "127.0.0.1", port: shared.config.bindPort).wait()
        Logger.log(["stage": "startup", "port": shared.config.bindPort])
        try channel.closeFuture.wait()
    }
}

@available(macOS 14.0, *)
final class AppSharedState {
    let configDir: URL
    let config: VisiondConfig
    let targetsConfig: TargetsConfig
    let capture: CaptureManager
    let ocr: VisionOCR
    let tesseract: TesseractOCR
    let health: Healthz

    init(configDir: URL) {
        self.configDir = configDir
        self.config = VisiondConfig.load(from: configDir.appendingPathComponent("visiond.json"))
        self.targetsConfig = TargetsConfig.load(from: configDir.appendingPathComponent("targets.json"))
        self.capture = CaptureManager(targets: targetsConfig, config: config)
        self.ocr = VisionOCR(languages: config.ocr.languages, minTextHeight: config.ocr.minTextHeightPx)
        self.tesseract = TesseractOCR(language: config.ocr.fallbackLanguage)
        self.health = Healthz()
    }
}

@available(macOS 14.0, *)
final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    let shared: AppSharedState
    var buffer: ByteBuffer!
    var requestBody: Data = Data()
    var currentHead: HTTPRequestHead?

    init(shared: AppSharedState) {
        self.shared = shared
    }

    func channelActive(context: ChannelHandlerContext) {
        buffer = context.channel.allocator.buffer(capacity: 0)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        switch reqPart {
        case .head(let head):
            currentHead = head
            requestBody.removeAll(keepingCapacity: true)
        case .body(var body):
            if let bytes = body.readBytes(length: body.readableBytes) {
                requestBody.append(contentsOf: bytes)
            }
        case .end:
            handleRequest(context: context)
        }
    }

    func handleRequest(context: ChannelHandlerContext) {
        guard let head = currentHead else { return }
        let path = head.uri
        if head.method == .GET && path == "/healthz" {
            respondJSON(context: context, status: .ok, json: shared.health.snapshot())
            return
        }
        if head.method == .POST && path == "/capture_once" {
            handleCaptureOnce(context: context)
            return
        }
        respondJSON(context: context, status: .notFound, json: ["error":"not found"]) 
    }

    func respondJSON(context: ChannelHandlerContext, status: HTTPResponseStatus, json: Any) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        let data = (try? JSONSerialization.data(withJSONObject: json, options: [])) ?? Data("{}".utf8)
        var buffer = context.channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func handleCaptureOnce(context: ChannelHandlerContext) {
        do {
            guard let payload = try JSONSerialization.jsonObject(with: requestBody, options: []) as? [String: Any],
                  let paneId = payload["pane_id"] as? String else {
                return respondJSON(context: context, status: .badRequest, json: ["error": "missing pane_id"])
            }

            let captureStart = Date()
            guard let captureResult = shared.capture.captureOnce(paneId: paneId) else {
                return respondJSON(context: context, status: .notFound, json: ["error": "pane_not_configured"])
            }
            let captureLatency = Int(Date().timeIntervalSince(captureStart) * 1000)

            var ocrTokens: [OCRToken] = []
            var engine = "vision"
            var ocrLatencyMs = 0
            if let image = captureResult.image {
                let start = Date()
                ocrTokens = shared.ocr.recognize(image: image)
                let meanConfidence = ocrTokens.map { $0.confidence }.reduce(0, +) / Double(max(1, ocrTokens.count))
                if (ocrTokens.isEmpty || meanConfidence < shared.config.ocr.minConfidencePrimary) && shared.config.ocr.fallback {
                    ocrTokens = shared.tesseract.recognize(image: image)
                    engine = "tesseract"
                }
                ocrLatencyMs = Int(Date().timeIntervalSince(start) * 1000)
            }

            shared.health.record(pane: paneId, stage: "locate", latencyMs: captureResult.locateLatencyMs, timestamp: captureResult.timestamp)
            shared.health.record(pane: paneId, stage: "capture", latencyMs: captureResult.captureLatencyMs, timestamp: captureResult.timestamp)
            shared.health.record(pane: paneId, stage: engine, latencyMs: ocrLatencyMs, count: max(1, ocrTokens.count), timestamp: Date())

            Logger.log([
                "stage": "capture",
                "pane": paneId,
                "capture_latency_ms": captureLatency,
                "locate_latency_ms": captureResult.locateLatencyMs,
                "map_crop_latency_ms": captureResult.mapCropLatencyMs ?? -1,
                "ocr_engine": engine,
                "ocr_tokens": ocrTokens.count
            ])

            var response: [String: Any] = [
                "pane": paneId,
                "ts": ISO8601DateFormatter().string(from: captureResult.timestamp),
                "sensors": captureResult.sensors.map(Self.encodeSensor),
                "metadata": Self.encodeMetadata(captureResult.metadata),
                "ocr": [
                    "engine": engine,
                    "tokens": ocrTokens.map { $0.json }
                ]
            ]
            if let mapMs = captureResult.mapCropLatencyMs { response["map_crop_latency_ms"] = mapMs }
            if let image = captureResult.image, let imageDict = Self.encodeImage(image) {
                response["image"] = imageDict
            }

            respondJSON(context: context, status: .ok, json: response)
        } catch {
            respondJSON(context: context, status: .internalServerError, json: ["error": "invalid json"])
        }
    }

    private static func encodeSensor(_ sensor: SensorReading) -> [String: Any] {
        var dict: [String: Any] = ["source": sensor.source]
        if let frame = sensor.frame {
            dict["frame"] = [
                "x": frame.origin.x,
                "y": frame.origin.y,
                "w": frame.size.width,
                "h": frame.size.height
            ]
        }
        if let text = sensor.text { dict["text"] = text }
        if let confidence = sensor.confidence { dict["confidence"] = confidence }
        return dict
    }

    private static func encodeMetadata(_ metadata: FrameMetadata) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let rect = metadata.contentRectPoints {
            dict["content_rect"] = ["x": rect.origin.x, "y": rect.origin.y, "w": rect.size.width, "h": rect.size.height]
        }
        if let scale = metadata.scaleFactor { dict["scale_factor"] = scale }
        if let contentScale = metadata.contentScale { dict["content_scale"] = contentScale }
        if let size = metadata.imageSize { dict["image_size"] = ["w": size.width, "h": size.height] }
        if let hash = metadata.perceptualHash { dict["phash"] = hash }
        return dict
    }

    private static func encodeImage(_ image: CGImage) -> [String: Any]? {
        guard let data = image.pngData() else { return nil }
        return [
            "encoding": "base64_png",
            "data": data.base64EncodedString()
        ]
    }
}
