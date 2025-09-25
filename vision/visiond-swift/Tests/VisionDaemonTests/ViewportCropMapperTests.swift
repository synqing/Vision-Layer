import XCTest
@testable import VisionDaemon
import CoreGraphics

final class ViewportCropMapperTests: XCTestCase {

    private func att(_ contentRectPoints: CGRect, _ scaleFactor: CGFloat, _ contentScale: CGFloat) -> FrameAttachments {
        FrameAttachments(contentRectPoints: contentRectPoints, scaleFactor: scaleFactor, contentScale: contentScale)
    }

    private let vp = DOMViewport(width: 1440, height: 900)
    private let chip = DOMBBox(x: 1088.0, y: 92.0, width: 252.0, height: 40.0)

    func test_map_retina2x_noOffsets() throws {
        let attachments = att(CGRect(x: 20, y: 40, width: 1200, height: 800), 2.0, 2.0)
        let expectedVisiblePx = CGRect(x: 40, y: 80, width: 2400, height: 1600)

        let rect = try mapDOMBBoxToPixelCrop(domBBox: chip, viewport: vp, attachments: attachments, inset: .zero)

        XCTAssertEqual(expectedVisiblePx.origin.x, 40, accuracy: 0.5)
        XCTAssertEqual(expectedVisiblePx.origin.y, 80, accuracy: 0.5)
        XCTAssertEqual(expectedVisiblePx.width, 2400, accuracy: 0.5)
        XCTAssertEqual(expectedVisiblePx.height, 1600, accuracy: 0.5)

        // sx = 2400/1440, sy = 1600/900
        XCTAssertEqual(rect.origin.x, 1855, accuracy: 2.0)
        XCTAssertEqual(rect.origin.y, 244, accuracy: 2.0)
        XCTAssertEqual(rect.width, 420, accuracy: 2.0)
        XCTAssertEqual(rect.height, 71, accuracy: 2.0)
    }

    func test_map_nonRetina1x_withInset() throws {
        let attachments = att(CGRect(x: 100, y: 200, width: 1000, height: 700), 1.0, 1.0)
        let inset = ViewportPixelInset(dx: 2, dy: 3, dw: 4, dh: 5)
        let rect = try mapDOMBBoxToPixelCrop(domBBox: chip, viewport: vp, attachments: attachments, inset: inset)

        // Expected roughly (after inset): (856, 275, 171, 26)
        XCTAssertEqual(rect.origin.x, 856, accuracy: 2.0)
        XCTAssertEqual(rect.origin.y, 275, accuracy: 2.0)
        XCTAssertEqual(rect.width, 171, accuracy: 2.0)
        XCTAssertEqual(rect.height, 26, accuracy: 2.0)
    }

    func test_invalidViewport_throws() {
        let attachments = att(CGRect(x: 0, y: 0, width: 800, height: 600), 2.0, 2.0)
        XCTAssertThrowsError(try mapDOMBBoxToPixelCrop(domBBox: chip, viewport: DOMViewport(width: 0, height: 0), attachments: attachments))
    }

    func test_invalidBBox_throws() {
        let attachments = att(CGRect(x: 0, y: 0, width: 800, height: 600), 2.0, 2.0)
        XCTAssertThrowsError(try mapDOMBBoxToPixelCrop(domBBox: DOMBBox(x: 0, y: 0, width: 0, height: 10), viewport: vp, attachments: attachments))
    }
}

