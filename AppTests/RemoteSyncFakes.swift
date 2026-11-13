import Foundation
import GarminAPI
import Synchronization
@testable import trAIning

final class MemoryKeyStore: APIKeyStore {
    private let value: Mutex<String?>

    init(_ initial: String? = nil) {
        value = Mutex(initial)
    }

    func read() throws -> String? { value.withLock { $0 } }
    func save(_ key: String) throws { value.withLock { $0 = key } }
    func delete() throws { value.withLock { $0 = nil } }
}

struct FakeAuthenticator: DeviceOwnerAuthenticating {
    let result: DeviceOwnerResult
    func authenticate(reason: String) async -> DeviceOwnerResult { result }
}

final class FakeClipboard: KeyClipboard {
    private let copied = Mutex<[String]>([])
    var values: [String] { copied.withLock { $0 } }
    func copy(_ key: String) { copied.withLock { $0.append(key) } }
}

final class FakeSyncServer: HTTPTransport {
    enum Reply {
        case status(Int, String)
        case offline
    }

    private struct State {
        var replies: [String: [Reply]] = [:]
        var requests: [URLRequest] = []
        var inFlight = 0
        var maxInFlight = 0
    }

    private let state = Mutex(State())
    private let delay: Duration

    init(delay: Duration = .zero, _ replies: [String: [Reply]] = [:]) {
        self.delay = delay
        state.withLock { $0.replies = replies }
    }

    var requests: [String] {
        state.withLock { $0.requests.map { "\($0.httpMethod ?? "") \($0.url?.path ?? "")" } }
    }

    var maxInFlight: Int { state.withLock { $0.maxInFlight } }

    var pushedIds: [String] {
        state.withLock { state in
            state.requests.filter { $0.httpMethod == "POST" && $0.url?.path == "/api/v1/changes" }.flatMap { request -> [String] in
                guard let body = request.httpBody,
                      let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                      let records = json["records"] as? [[String: Any]]
                else { return [] }
                return records.compactMap { $0["id"] as? String }
            }
        }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let route = "\(request.httpMethod ?? "") \(request.url?.path ?? "")"
        let reply = state.withLock { state -> Reply in
            state.requests.append(request)
            state.inFlight += 1
            state.maxInFlight = max(state.maxInFlight, state.inFlight)
            guard var queue = state.replies[route], !queue.isEmpty else { return Self.defaultReply(route) }
            let next = queue.removeFirst()
            state.replies[route] = queue.isEmpty ? [next] : queue
            return next
        }
        defer { state.withLock { $0.inFlight -= 1 } }
        if delay > .zero { try await Task.sleep(for: delay) }
        switch reply {
        case .offline:
            throw URLError(.notConnectedToInternet)
        case .status(let code, let body):
            let http = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), http)
        }
    }

    private static func defaultReply(_ route: String) -> Reply {
        switch route {
        case "POST /api/v1/account": .status(201, "{}")
        case "DELETE /api/v1/account": .status(204, "")
        case "POST /api/v1/changes": .status(200, #"{"cursor":1,"ignored":[]}"#)
        default: .status(200, #"{"records":[],"cursor":1,"hasMore":false}"#)
        }
    }
}
