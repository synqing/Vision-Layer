import Foundation
import CoreGraphics

@available(macOS 13.0, *)
final class GeometryMapper {
    func resolveROI(target: TargetEntry, sensors: [SensorReading], attachments: FrameAttachments?, image: CGImage) -> CGRect? {
        if let structured = sensors.first(where: { $0.frame != nil }) {
            return map(frame: structured.frame!, target: target, attachments: attachments, image: image)
        }
        if let pixel = target.pixel {
            let rect = CGRect(x: pixel.roi.x, y: pixel.roi.y, width: pixel.roi.w, height: pixel.roi.h)
            return clamp(rect: rect, maxSize: CGSize(width: image.width, height: image.height))
        }
        return nil
    }

    private func map(frame: CGRect, target: TargetEntry, attachments: FrameAttachments?, image: CGImage) -> CGRect {
        let defaultRect = CGRect(origin: .zero, size: CGSize(width: image.width, height: image.height))
        guard let attachments else {
            return clamp(rect: frame, maxSize: defaultRect.size)
        }

        var mapped = CGRect.zero
        mapped.origin.x = (frame.origin.x - attachments.contentRectPoints.origin.x) * attachments.scaleFactor
        mapped.origin.y = (frame.origin.y - attachments.contentRectPoints.origin.y) * attachments.scaleFactor
        mapped.size.width = frame.size.width * attachments.scaleFactor
        mapped.size.height = frame.size.height * attachments.scaleFactor

        if let offset = target.pixelOffset {
            mapped.origin.x += CGFloat(offset.dx)
            mapped.origin.y += CGFloat(offset.dy)
            mapped.size.width = CGFloat(offset.w)
            mapped.size.height = CGFloat(offset.h)
        }

        return clamp(rect: mapped, maxSize: defaultRect.size)
    }

    private func clamp(rect: CGRect, maxSize: CGSize) -> CGRect {
        var adjusted = rect
        if adjusted.origin.x < 0 { adjusted.origin.x = 0 }
        if adjusted.origin.y < 0 { adjusted.origin.y = 0 }
        let maxWidth = CGFloat(maxSize.width)
        let maxHeight = CGFloat(maxSize.height)
        if adjusted.maxX > maxWidth { adjusted.size.width = maxWidth - adjusted.origin.x }
        if adjusted.maxY > maxHeight { adjusted.size.height = maxHeight - adjusted.origin.y }
        return adjusted
    }
}
