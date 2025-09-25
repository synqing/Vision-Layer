//
//  Cropper.swift
//  VisionDaemon
//
//  Convert CMSampleBuffer -> CGImage and crop to the requested rect.
//

import Foundation
import CoreMedia
import CoreGraphics
import VideoToolbox

public enum CropperError: Error {
    case noPixelBuffer
    case vtImageFailed(OSStatus)
    case emptyCrop
}

public func cropCGImage(from sampleBuffer: CMSampleBuffer, cropRect: CGRect) throws -> CGImage {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        throw CropperError.noPixelBuffer
    }
    var cgImageOut: CGImage?
    let status = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImageOut)
    guard status == noErr, let cgImage = cgImageOut else {
        throw CropperError.vtImageFailed(status)
    }
    guard !cropRect.isEmpty else { throw CropperError.emptyCrop }
    guard let cropped = cgImage.cropping(to: cropRect) else {
        throw CropperError.emptyCrop
    }
    return cropped
}
