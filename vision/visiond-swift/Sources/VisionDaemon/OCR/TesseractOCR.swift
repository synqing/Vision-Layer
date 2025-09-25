import Foundation
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

final class TesseractOCR {
    private let language: String
    init(language: String) { self.language = language }

    func recognize(image: CGImage) -> [OCRToken] {
        guard let pngURL = writeTempPNG(image: image) else { return [] }
        defer { try? FileManager.default.removeItem(at: pngURL) }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["tesseract", pngURL.path, "stdout", "-l", language, "--psm", "6", "tsv"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        do { try proc.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return parseTSV(text: text)
    }

    private func writeTempPNG(image: CGImage) -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".png")
        let type = UTType.png.identifier as CFString
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return url
    }

    private func parseTSV(text: String) -> [OCRToken] {
        var tokens: [OCRToken] = []
        let lines = text.split(separator: "\n")
        guard let header = lines.first else { return [] }
        let cols = header.split(separator: "\t").map(String.init)
        let map = Dictionary(uniqueKeysWithValues: cols.enumerated().map { ($1, $0) })
        for line in lines.dropFirst() {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == cols.count else { continue }
            guard let level = Int(parts[map["level"] ?? 0]), level >= 5 else { continue }
            let text = parts[map["text"] ?? 0]
            if text.isEmpty { continue }
            let conf = Double(parts[map["conf"] ?? 0]) ?? 0
            let x = Double(parts[map["left"] ?? 0]) ?? 0
            let y = Double(parts[map["top"] ?? 0]) ?? 0
            let w = Double(parts[map["width"] ?? 0]) ?? 0
            let h = Double(parts[map["height"] ?? 0]) ?? 0
            // Bounding boxes are absolute pixels in source image; normalize is deferred to parser if needed.
            tokens.append(OCRToken(text: text, bbox: [x, y, w, h], confidence: conf / 100.0))
        }
        return tokens
    }
}
