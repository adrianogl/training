import Foundation
import Synchronization
@testable import GarminAPI

final class StubTransport: HTTPTransport {
    enum Response {
        case ok(String)
        case status(Int, String)
    }

    private struct State {
        var queue: [Response]
        var requests: [URLRequest] = []
    }

    private let state: Mutex<State>

    init(_ responses: [Response]) {
        state = Mutex(State(queue: responses))
    }

    var requests: [URLRequest] {
        state.withLock { $0.requests }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: .milliseconds(20))
        let response = state.withLock { state -> Response? in
            state.requests.append(request)
            return state.queue.isEmpty ? nil : state.queue.removeFirst()
        }
        guard let response else { throw URLError(.badServerResponse) }
        let (status, body): (Int, String)
        switch response {
        case .ok(let text): (status, body) = (200, text)
        case .status(let code, let text): (status, body) = (code, text)
        }
        let http = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), http)
    }
}
