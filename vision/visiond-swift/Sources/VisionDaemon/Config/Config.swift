import Foundation

struct VisiondConfig: Codable {
    struct StreamSettings: Codable {
        let defaultFps: Int
        let maxFramesInFlight: Int
    }

    struct ScreenshotSettings: Codable {
        let enabled: Bool
        let cooldownMs: Int
    }

    struct OCRSettings: Codable {
        let languages: [String]
        let fallback: Bool
        let fallbackEngine: String
        let fallbackLanguage: String
        let minConfidencePrimary: Double
        let minTextHeightPx: Double
    }

    struct SensorSettings: Codable {
        let axPollIntervalMs: Int
        let domPollIntervalMs: Int
        let domBrowser: String
        let playwrightLaunchArgs: [String]
    }

    struct HashingSettings: Codable {
        let enabled: Bool
        let mode: String
        let bits: Int
    }

    let bindPort: Int
    let stream: StreamSettings
    let screenshot: ScreenshotSettings
    let ocr: OCRSettings
    let sensors: SensorSettings
    let hashing: HashingSettings
    let throttleMs: Int

    static func load(from url: URL) -> VisiondConfig {
        if let data = try? Data(contentsOf: url), let cfg = try? JSONDecoder().decode(VisiondConfig.self, from: data) {
            return cfg
        }
        let envPort = Int(ProcessInfo.processInfo.environment["VISIOND_PORT"] ?? "8765") ?? 8765
        let envLangs = (ProcessInfo.processInfo.environment["OCR_LANGS"] ?? "en-US").split(separator: ",").map { String($0) }
        let fallback = (ProcessInfo.processInfo.environment["FALLBACK_OCR"] ?? "off").lowercased() == "on"
        return VisiondConfig(
            bindPort: envPort,
            stream: .init(defaultFps: 2, maxFramesInFlight: 3),
            screenshot: .init(enabled: true, cooldownMs: 750),
            ocr: .init(languages: envLangs.isEmpty ? ["en-US"] : envLangs,
                       fallback: fallback,
                       fallbackEngine: "tesseract",
                       fallbackLanguage: "eng",
                       minConfidencePrimary: 0.9,
                       minTextHeightPx: 10.0),
            sensors: .init(axPollIntervalMs: 500,
                           domPollIntervalMs: 1000,
                           domBrowser: "chromium",
                           playwrightLaunchArgs: ["--disable-dev-shm-usage"]),
            hashing: .init(enabled: true, mode: "dhash", bits: 64),
            throttleMs: 0
        )
    }
}

enum TargetMode: String, Codable {
    case ax
    case dom
    case pixel
}

struct DOMTarget: Codable {
    let urlContains: String?
    let locator: String
}

struct AXTarget: Codable {
    let role: String?
    let titleContains: String?
    let index: Int?
}

struct PixelROI: Codable {
    let x: Int
    let y: Int
    let w: Int
    let h: Int
}

struct PixelTarget: Codable {
    let windowTitleContains: String
    let roi: PixelROI
}

struct PixelOffset: Codable {
    let dx: Int
    let dy: Int
    let w: Int
    let h: Int
}

struct TargetEntry: Codable {
    let mode: TargetMode
    let app: String
    let dom: DOMTarget?
    let ax: AXTarget?
    let pixel: PixelTarget?
    let pixelOffset: PixelOffset?
    let multiReadN: Int?
}

struct TargetsConfig: Codable {
    let panes: [String: TargetEntry]

    static func load(from url: URL) -> TargetsConfig {
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([String: TargetEntry].self, from: data) {
                return TargetsConfig(panes: decoded)
            }
        }
        return TargetsConfig(panes: [:])
    }
}
