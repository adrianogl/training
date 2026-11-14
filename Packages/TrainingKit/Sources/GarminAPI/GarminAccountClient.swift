import Foundation

public protocol GarminSessionStore: Sendable {
    func load() throws -> GarminAccountSession?
    func save(_ session: GarminAccountSession) throws
}

public actor GarminAccountClient {
    private typealias E = GarminAccountEndpoints

    private let transport: HTTPTransport
    private let store: GarminSessionStore
    private let auth: GarminAccountAuth
    private let now: @Sendable () -> Date

    public init(transport: HTTPTransport, store: GarminSessionStore, now: @escaping @Sendable () -> Date = { .now }) {
        self.transport = transport
        self.store = store
        self.auth = GarminAccountAuth(transport: transport)
        self.now = now
    }

    public func get(_ pathAndQuery: String) async throws -> Data {
        try await send(pathAndQuery, method: "GET", body: nil)
    }

    public func post(_ pathAndQuery: String, body: Data) async throws -> Data {
        try await send(pathAndQuery, method: "POST", body: body)
    }

    private func send(_ pathAndQuery: String, method: String, body: Data?) async throws -> Data {
        var session = try currentSession()
        if session.expiresAt.timeIntervalSince(now()) < E.refreshMargin {
            session = try await auth.refresh(session)
            try store.save(session)
        }
        let (data, response) = try await transport.send(request(pathAndQuery, token: session.accessToken, method: method, body: body))
        if response.statusCode == 401 {
            let renewed = try await auth.refresh(session)
            try store.save(renewed)
            let (retryData, retry) = try await transport.send(request(pathAndQuery, token: renewed.accessToken, method: method, body: body))
            guard (200..<300).contains(retry.statusCode) else { throw GarminAccountError.unexpectedResponse(status: retry.statusCode) }
            return retryData
        }
        if response.statusCode == 429 { throw GarminAccountError.rateLimited }
        guard (200..<300).contains(response.statusCode) else { throw GarminAccountError.unexpectedResponse(status: response.statusCode) }
        return data
    }

    private func currentSession() throws -> GarminAccountSession {
        guard let session = try store.load() else { throw GarminAccountError.sessionExpired }
        return session
    }

    private func request(_ pathAndQuery: String, token: String, method: String, body: Data?) -> URLRequest {
        var request = URLRequest(url: URL(string: E.apiBase.absoluteString + pathAndQuery)!)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (field, value) in E.nativeHeaders { request.setValue(value, forHTTPHeaderField: field) }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
