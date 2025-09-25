import Foundation
import AppKit
import ApplicationServices

@available(macOS 14.0, *)
final class AXResolver {
    private enum AXAttr {
        static let children: CFString = "AXChildren" as CFString
        static let role: CFString = "AXRole" as CFString
        static let title: CFString = "AXTitle" as CFString
        static let frame: CFString = "AXFrame" as CFString
        static let value: CFString = "AXValue" as CFString
        static let help: CFString = "AXHelp" as CFString
    }
    func resolve(appBundleId: String, target: AXTarget) -> SensorReading? {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: appBundleId)
        for app in apps {
            guard let element = resolveElement(for: app, target: target) else { continue }
            let frame = readFrame(of: element)
            let text = readText(of: element)
            let confidence = text?.isEmpty == false ? 1.0 : 0.7
            return SensorReading(source: "ax", frame: frame, text: text, confidence: confidence)
        }
        return nil
    }

    private func resolveElement(for app: NSRunningApplication, target: AXTarget) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        return findMatch(in: axApp, target: target, depth: 0)
    }

    private func findMatch(in element: AXUIElement, target: AXTarget, depth: Int) -> AXUIElement? {
        if depth > 6 { return nil }
        if matches(element: element, target: target) { return element }
        var childrenValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, AXAttr.children, &childrenValue)
        guard result == .success, let array = childrenValue as? [AXUIElement] else { return nil }
        for child in array {
            if let match = findMatch(in: child, target: target, depth: depth + 1) { return match }
        }
        return nil
    }

    private func matches(element: AXUIElement, target: AXTarget) -> Bool {
        if let expectedRole = target.role {
            if let role = copyAttribute(element, AXAttr.role) as? String, role != expectedRole { return false }
        }
        if let titleFragment = target.titleContains?.lowercased() {
            if let title = copyAttribute(element, AXAttr.title) as? String {
                if !title.lowercased().contains(titleFragment) { return false }
            } else {
                return false
            }
        }
        return true
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value
    }

    private func readFrame(of element: AXUIElement) -> CGRect? {
        guard let valueRef = copyAttribute(element, AXAttr.frame) else { return nil }
        let value = unsafeBitCast(valueRef, to: AXValue.self)
        var rect = CGRect.zero
        if AXValueGetType(value) == .cgRect, AXValueGetValue(value, .cgRect, &rect) {
            return rect
        }
        return nil
    }

    private func readText(of element: AXUIElement) -> String? {
        if let value = copyAttribute(element, AXAttr.value) as? String {
            return value
        }
        if let help = copyAttribute(element, AXAttr.help) as? String {
            return help
        }
        return nil
    }
}
