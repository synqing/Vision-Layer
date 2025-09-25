//
//  ViewportCropMapper.swift
//  VisionDaemon
//
//  Maps a viewport-relative DOM bounding box to pixel coordinates within the
//  current ScreenCaptureKit frame using per-frame attachments.
//

import Foundation
import CoreGraphics

public struct ViewportPixelInset {
    public var dx: CGFloat
    public var dy: CGFloat
    public var dw: CGFloat
    public var dh: CGFloat
    public static let zero = ViewportPixelInset(dx: 0, dy: 0, dw: 0, dh: 0)
}

public enum ViewportMapperError: Error {
    case invalidViewport
    case invalidBBox
}

public func mapDOMBBoxToPixelCrop(
    domBBox: DOMBBox,
    viewport: DOMViewport,
    attachments: FrameAttachments,
    inset: ViewportPixelInset = .zero
) throws -> CGRect {
    guard viewport.width > 0, viewport.height > 0 else { throw ViewportMapperError.invalidViewport }
    guard domBBox.width > 0, domBBox.height > 0 else { throw ViewportMapperError.invalidBBox }

    let visiblePxOriginX = attachments.contentRectPoints.origin.x * attachments.scaleFactor
    let visiblePxOriginY = attachments.contentRectPoints.origin.y * attachments.scaleFactor
    let visiblePxWidth = attachments.contentRectPoints.size.width * attachments.scaleFactor
    let visiblePxHeight = attachments.contentRectPoints.size.height * attachments.scaleFactor
    let visibleRect = CGRect(x: visiblePxOriginX, y: visiblePxOriginY, width: visiblePxWidth, height: visiblePxHeight)

    let sx = visibleRect.width / CGFloat(viewport.width)
    let sy = visibleRect.height / CGFloat(viewport.height)

    let cropX = visibleRect.minX + CGFloat(domBBox.x) * sx + inset.dx
    let cropY = visibleRect.minY + CGFloat(domBBox.y) * sy + inset.dy
    let cropW = CGFloat(domBBox.width) * sx - inset.dw
    let cropH = CGFloat(domBBox.height) * sy - inset.dh

    var rect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
    rect = rect.intersection(visibleRect)
    return rect.integral
}
