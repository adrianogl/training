import Foundation
import GarminAPI
import Metrics
import Testing
@testable import trAIning

private final class CourseTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body = #"{"courseName":"Pampulha 10Km","geoPoints":[{"latitude":-19.850,"longitude":-43.970,"elevation":800,"distance":0},{"latitude":-19.851,"longitude":-43.971,"elevation":805,"distance":150},{"latitude":-19.852,"longitude":-43.972,"elevation":802,"distance":300}]}"#
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@Suite struct CourseImportTests {
    @Test func garminCourseBecomesProfileForStrategy() async throws {
        let store = KeychainGarminSessionStore(keychain: MemoryKeyStore())
        try store.save(GarminAccountSession(accessToken: "t", refreshToken: "r", clientId: "C", expiresAt: .distantFuture))
        let client = GarminAccountClient(transport: CourseTransport(), store: store)

        let data = try await GarminCourses.gpx(client: client, id: 7)
        let profile = try gpxProfile(data)

        #expect(profile.count == 3)
        #expect(profile.map(\.altitude) == [800, 805, 802])
        #expect(profile.last!.distance > 200)
    }
}
