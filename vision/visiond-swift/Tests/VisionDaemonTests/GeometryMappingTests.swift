import XCTest
@testable import VisionDaemon
import CoreGraphics

final class GeometryMappingTests: XCTestCase {
    func testMapDOMBBoxToPixelCrop_basicScaling() throws {
        // Visible content rect is 100x50 points at 2x scale => 200x100 px
        let attachments = FrameAttachments(
            contentRectPoints: CGRect(x: 10, y: 20, width: 100, height: 50),
            scaleFactor: 2.0,
            contentScale: 2.0
        )
        // Viewport is 1000x500 CSS px; bbox sits at 100x50 w:200 h:100 CSS px
        let viewport = DOMViewport(width: 1000, height: 500)
        let bbox = DOMBBox(x: 100, y: 50, width: 200, height: 100)

        // Expected: visible rect (px) is at (20,40) w:200 h:100
        // sx = 200/1000 = 0.2; sy = 100/500 = 0.2
        // crop.x = 20 + 100*0.2 = 40; crop.y = 40 + 50*0.2 = 50
        // crop.w = 200*0.2 = 40; crop.h = 100*0.2 = 20
        let rect = try mapDOMBBoxToPixelCrop(domBBox: bbox, viewport: viewport, attachments: attachments)
        XCTAssertEqual(rect.origin.x, 40, accuracy: 0.5)
        XCTAssertEqual(rect.origin.y, 50, accuracy: 0.5)
        XCTAssertEqual(rect.size.width, 40, accuracy: 0.5)
        XCTAssertEqual(rect.size.height, 20, accuracy: 0.5)
    }

    func testMapDOMBBoxToPixelCrop_clampedToVisibleRect() throws {
        let attachments = FrameAttachments(
            contentRectPoints: CGRect(x: 0, y: 0, width: 100, height: 100),
            scaleFactor: 2.0,
            contentScale: 2.0
        )
        let viewport = DOMViewport(width: 1000, height: 1000)
        // BBox extends beyond viewport (bottom-right), mapping must intersect visible rect.
        let bbox = DOMBBox(x: 900, y: 900, width: 200, height: 200)
        let rect = try mapDOMBBoxToPixelCrop(domBBox: bbox, viewport: viewport, attachments: attachments)
        // Visible rect (px): (0,0,200,200). Mapped rect before intersection would be (180,180,40,40) -> still within, but integralization clamps.
        XCTAssertTrue(rect.maxX <= 200)
        XCTAssertTrue(rect.maxY <= 200)
        XCTAssertGreaterThan(rect.width, 0)
        XCTAssertGreaterThan(rect.height, 0)
    }
}

