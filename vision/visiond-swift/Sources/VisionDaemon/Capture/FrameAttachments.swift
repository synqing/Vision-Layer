//
//  FrameAttachments.swift
//  VisionDaemon
//
//  Helpers for reading ScreenCaptureKit per-frame attachments.
//

import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreGraphics

public struct FrameAttachments {
    public let contentRectPoints: CGRect
    public let scaleFactor: CGFloat
    public let contentScale: CGFloat
}

public enum AttachmentError: Error {
    case missing
    case corrupt
}

public func readFrameAttachments(from sampleBuffer: CMSampleBuffer) throws -> FrameAttachments {
    let contentRectKey = SCStreamFrameInfo.contentRect.rawValue as CFString
    let scaleFactorKey = SCStreamFrameInfo.scaleFactor.rawValue as CFString
    let contentScaleKey = SCStreamFrameInfo.contentScale.rawValue as CFString

    var mode = CMAttachmentMode()
    guard let rectRef = CMGetAttachment(sampleBuffer, key: contentRectKey, attachmentModeOut: &mode) else {
        throw AttachmentError.missing
    }
    let rectDict = unsafeBitCast(rectRef, to: CFDictionary.self)
    guard let contentRect = CGRect(dictionaryRepresentation: rectDict) else {
        throw AttachmentError.corrupt
    }
    guard let scaleNumber = CMGetAttachment(sampleBuffer, key: scaleFactorKey, attachmentModeOut: &mode) as? NSNumber,
          let contentScaleNumber = CMGetAttachment(sampleBuffer, key: contentScaleKey, attachmentModeOut: &mode) as? NSNumber
    else { throw AttachmentError.corrupt }

    return FrameAttachments(
        contentRectPoints: contentRect,
        scaleFactor: CGFloat(truncating: scaleNumber),
        contentScale: CGFloat(truncating: contentScaleNumber)
    )
}
