//
//  DOMBridgeClient.swift
//  VisionDaemon
//
//  Minimal client for the local Playwright DOM bridge.
//

import Foundation

public struct DOMBBox: Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

public struct DOMViewport: Codable {
    public let width: Int
    public let height: Int
}

public struct DOMLocateRequest: Codable {
    public var app: String?
    public var url_contains: String?
    public var seed_url: String?
    public var wait_until: String? = "domcontentloaded"
    public var timeout_ms: Int? = 8000
    public var selector: [String: String]
    public var scroll: Bool? = true
}

public struct DOMLocateResponse: Codable {
    public let ok: Bool
    public let url: String?
    public let viewport: DOMViewport?
    public let bbox: DOMBBox?
    public let inner_text: String?
    public let meta: [String: String]?
}

public final class DOMBridgeClient {
    public struct Config {
        public var host: String = "127.0.0.1"
        public var port: Int = 4321
        public init() {}
    }

    private let cfg: Config
    private let session: URLSession

    public init(config: Config = .init(), session: URLSession = .shared) {
        self.cfg = config
        self.session = session
    }

    public func locate(_ req: DOMLocateRequest) async throws -> DOMLocateResponse {
        let url = URL(string: "http://\(cfg.host):\(cfg.port)/dom/locate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(req)

        let (data, resp) = try await session.data(for: request)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "DOMBridgeClient", code: httpStatus(resp), userInfo: [NSLocalizedDescriptionKey: "DOM bridge returned non-success status"])
        }
        return try JSONDecoder().decode(DOMLocateResponse.self, from: data)
    }

    private func httpStatus(_ response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? -1
    }
}
