import Foundation

public actor TokenProvider {
    private static let refreshMargin: TimeInterval = 3600

    private let apiKey: String
    private let baseURL: URL
    private let transport: HTTPTransport
    private let now: @Sendable () -> Date
    private var cached: (token: String, expiry: Date)?
    private var inFlight: Task<String, Error>?

    public init(apiKey: String, baseURL: URL, transport: HTTPTransport, now: @escaping @Sendable () -> Date = { .now }) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.transport = transport
        self.now = now
    }

    public func bearer() async throws -> String {
        if let cached, cached.expiry.timeIntervalSince(now()) >= Self.refreshMargin {
            return cached.token
        }
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await self.refresh() }
        inFlight = task
        return try await task.value
    }

    private func refresh() async throws -> String {
        defer { inFlight = nil }
        let token = try await exchange()
        cached = (token, try Self.expiry(of: token))
        return token
    }

    public func invalidate() {
        cached = nil
    }

    private func exchange() async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: GarminEndpoints.tokenPath))
        request.httpMethod = "POST"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("ApiKey \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200..<300:
            break
        case 400, 401, 403:
            throw GarminAPIError.invalidKey
        case 429:
            throw GarminAPIError.rateLimited(path: GarminEndpoints.tokenPath)
        default:
            throw GarminAPIError.server(status: response.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8) else { throw GarminAPIError.invalidKey }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func expiry(of jwt: String) throws -> Date {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { throw GarminAPIError.invalidKey }
        var base64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = (json["exp"] as? NSNumber)?.doubleValue
        else { throw GarminAPIError.invalidKey }
        return Date(timeIntervalSince1970: exp)
    }
}
