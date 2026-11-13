import Foundation
import GarminAPI

public struct RemoteClient: Sendable {
    private typealias C = RemoteSyncConstants
    private let baseURL: URL
    private let bearer: String
    private let transport: any HTTPTransport

    public init(baseURL: URL, keys: RemoteKeys, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.bearer = keys.bearer
        self.transport = transport
    }

    public func createAccount() async throws {
        _ = try await send(method: "POST", path: C.accountPath, accepted: [200, 201])
    }

    public func deleteAccount() async throws {
        _ = try await send(method: "DELETE", path: C.accountPath, accepted: [204])
    }

    public func changes(since cursor: Int64) async throws -> RemoteChangesPage {
        let data = try await send(method: "GET", path: C.changesPath, query: [URLQueryItem(name: C.sinceQuery, value: String(cursor))])
        return try decode(data)
    }

    public func push(_ records: [RemoteRecord]) async throws -> RemotePushResult {
        let body = try RemoteJSON.encoder().encode(RemotePushBody(records: records))
        return try decode(try await send(method: "POST", path: C.changesPath, body: body))
    }

    private func send(method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil, accepted: Set<Int> = [200]) async throws -> Data {
        var url = baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.send(request)
        guard accepted.contains(response.statusCode) else { throw Self.error(for: response.statusCode, body: data) }
        return data
    }

    private func decode<Value: Decodable>(_ data: Data) throws -> Value {
        do {
            return try RemoteJSON.decoder().decode(Value.self, from: data)
        } catch {
            throw RemoteSyncError.decoding
        }
    }

    private static func error(for status: Int, body: Data) -> RemoteSyncError {
        if status == 413, (try? JSONDecoder().decode(RemoteErrorBody.self, from: body))?.error == C.quotaExceededCode {
            return .quotaExceeded
        }
        return switch status {
        case 400: .badRequest
        case 401: .unauthorized
        case 413: .payloadTooLarge
        case 429: .rateLimited
        case 500...: .server(status: status)
        default: .unexpectedStatus(status)
        }
    }
}
