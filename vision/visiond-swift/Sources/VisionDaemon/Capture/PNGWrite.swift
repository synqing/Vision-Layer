import Foundation
import ImageIO
import UniformTypeIdentifiers

public func writePNG(_ image: CGImage, url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "PNGWrite", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "PNGWrite", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize PNG"]) }
}
