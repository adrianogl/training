import Foundation
import Storage
import SwiftData
import SwiftUI

enum NavigationRestoration {
    static func encode<Value: Encodable>(_ value: Value) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    static func decodePath<Route: Decodable>(_ data: Data) -> [Route] {
        (try? JSONDecoder().decode([Route].self, from: data)) ?? []
    }

    static func decodeValue<Route: Decodable>(_ data: Data) -> Route? {
        try? JSONDecoder().decode(Route.self, from: data)
    }

    static func encode(_ path: NavigationPath) -> Data {
        guard let representation = path.codable else { return Data() }
        return encode(representation)
    }

    static func decodeNavigationPath(_ data: Data) -> NavigationPath {
        guard let representation = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: data) else {
            return NavigationPath()
        }
        return NavigationPath(representation)
    }

    static func validPrefix<Route>(_ path: [Route], isValid: (Route) -> Bool) -> [Route] {
        Array(path.prefix(while: isValid))
    }

    static func hasActivity(_ id: Int64, in context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.activityId == id })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    static func section(_ raw: String, allowed: [AppSection]) -> AppSection {
        AppSection(rawValue: raw).flatMap { allowed.contains($0) ? $0 : nil } ?? .today
    }
}
