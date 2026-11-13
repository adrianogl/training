import Foundation
import GarminAPI
import Synchronization

final class ScriptedTransport: HTTPTransport {
    enum Response {
        case json(Int, String)
        case failure(URLError.Code)
    }

    private struct State {
        var queue: [Response]
        var requests: [URLRequest] = []
    }

    private let state: Mutex<State>
    private let onSend: @Sendable (URLRequest) -> Void

    init(_ responses: [Response], onSend: @escaping @Sendable (URLRequest) -> Void = { _ in }) {
        state = Mutex(State(queue: responses))
        self.onSend = onSend
    }

    var requests: [URLRequest] {
        state.withLock { $0.requests }
    }

    var pushBodySizes: [Int] {
        requests.filter { $0.httpMethod == "POST" && $0.url?.path == "/api/v1/changes" }.map { $0.httpBody?.count ?? 0 }
    }

    var pushBodies: [[[String: Any]]] {
        requests.filter { $0.httpMethod == "POST" && $0.url?.path == "/api/v1/changes" }.compactMap { request in
            request.httpBody
                .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                .flatMap { $0["records"] as? [[String: Any]] }
        }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: .milliseconds(5))
        onSend(request)
        let response = state.withLock { state -> Response? in
            state.requests.append(request)
            return state.queue.isEmpty ? nil : state.queue.removeFirst()
        }
        guard let response else { throw URLError(.badServerResponse) }
        switch response {
        case .failure(let code):
            throw URLError(code)
        case .json(let status, let body):
            let http = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (Data(body.utf8), http)
        }
    }
}
