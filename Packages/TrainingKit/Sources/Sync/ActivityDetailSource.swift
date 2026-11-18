import FITReader

public protocol ActivityDetailSource: Sendable {
    func activitySummary(activityId: Int64) async throws -> FITSummary?
}
