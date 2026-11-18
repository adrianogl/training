import os

enum PerformanceTrace {
    private static let signposter = OSSignposter(subsystem: PerformanceTraceConstants.subsystem, category: PerformanceTraceConstants.category)

    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        defer { signposter.endInterval(name, state) }
        return try work()
    }

    static func measure<T>(
        _ name: StaticString, isolation: isolated (any Actor)? = #isolation, _ work: () async throws -> T
    ) async rethrows -> T {
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        defer { signposter.endInterval(name, state) }
        return try await work()
    }
}
