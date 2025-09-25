import Foundation
import CoreImage
import CoreGraphics

enum PerceptualHash {
    static func dHashHex(_ image: CGImage) -> String {
        let width = 9
        let height = 8
        let context = CIContext(options: nil)
        let ciImage = CIImage(cgImage: image).applyingFilter("CIPhotoEffectMono")
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: CGFloat(width) / ciImage.extent.width, y: CGFloat(height) / ciImage.extent.height))
        guard let cg = context.createCGImage(resized, from: CGRect(x: 0, y: 0, width: width, height: height)) else { return "" }
        guard let data = copyGrayPixels(cg) else { return "" }
        var bits: [UInt8] = []
        for y in 0..<height {
            for x in 0..<(width - 1) {
                let left = data[y * width + x]
                let right = data[y * width + x + 1]
                bits.append(left < right ? 1 : 0)
            }
        }
        var hex = ""
        for chunk in stride(from: 0, to: bits.count, by: 4) {
            var value: UInt8 = 0
            for i in 0..<4 { value = (value << 1) | (chunk + i < bits.count ? bits[chunk + i] : 0) }
            hex += String(format: "%1x", value)
        }
        return hex
    }

    private static func copyGrayPixels(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: 0) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}

