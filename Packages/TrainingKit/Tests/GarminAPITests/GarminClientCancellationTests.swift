import Foundation
import Synchronization
import Testing
@testable import GarminAPI

private final class RateLimitedTransport: HTTPTransport {
    private let gets = Mutex(0)

    var getCount: Int { gets.withLock { $0 } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let isGet = request.httpMethod == "GET"
        if isGet { gets.withLock { $0 += 1 } }
        let body = isGet ? "" : makeJWT(exp: Int(Date.now.timeIntervalSince1970) + 86_400 * 365)
        let response = HTTPURLResponse(url: request.url!, statusCode: isGet ? 429 : 200, httpVersion: nil, headerFields: [:])!
        return (Data(body.utf8), response)
    }
}

@Suite struct GarminClientCancellationTests {
    @Test func clientSleepRethrowsCancellation() async {
        let transport = RateLimitedTransport()
        let tokens = TokenProvider(apiKey: "k", baseURL: GarminEndpoints.base, transport: transport)
        let client = GarminClient(tokens: tokens, transport: transport)

        let task = Task { try await client.activities(start: 0, limit: 50, from: nil, to: nil) }
        task.cancel()
        let result = await task.result

        #expect(throws: CancellationError.self) { try result.get() }
        #expect(transport.getCount == 1)
    }
}
