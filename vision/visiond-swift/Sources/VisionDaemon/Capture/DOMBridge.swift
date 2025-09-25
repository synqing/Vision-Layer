import Foundation

@available(macOS 13.0, *)
final class DOMBridge {
    private let session = URLSession(configuration: .default)
    private let endpoint: URL?

    init() {
        if let portString = ProcessInfo.processInfo.environment["DOM_BRIDGE_PORT"], let port = Int(portString) {
            endpoint = URL(string: "http://127.0.0.1:\(port)/locate")
        } else {
            endpoint = nil
        }
    }

    func resolve(appBundleId: String, target: DOMTarget) -> SensorReading? {
        guard let endpoint else {
            Logger.log(["stage": "locate", "source": "dom", "event": "bridge_missing", "app": appBundleId])
            return nil
        }

        let payload: [String: Any] = [
            "app": appBundleId,
            "locator": target.locator,
            "url_contains": target.urlContains as Any
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        let semaphore = DispatchSemaphore(value: 0)
        var reading: SensorReading?

        session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            guard error == nil, let data else {
                if let error = error {
                    Logger.log(["stage": "locate", "source": "dom", "event": "request_error", "error": String(describing: error)])
                }
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let frame = DOMBridge.parseFrame(json["frame"]) 
            let text = json["text"] as? String
            let confidence = json["confidence"] as? Double ?? 0.9
            reading = SensorReading(source: "dom", frame: frame, text: text, confidence: confidence)
        }.resume()

        semaphore.wait()
        return reading
    }

    private static func parseFrame(_ value: Any?) -> CGRect? {
        guard let dict = value as? [String: Any],
              let x = dict["x"] as? Double,
              let y = dict["y"] as? Double,
              let w = dict["w"] as? Double,
              let h = dict["h"] as? Double else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

