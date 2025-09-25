import Foundation

enum Logger {
    static func log(_ obj: [String: Any]) {
        var dict = obj
        dict["ts"] = ISO8601DateFormatter().string(from: Date())
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            if let line = String(data: data, encoding: .utf8) {
                print(line)
            }
        }
    }
}

