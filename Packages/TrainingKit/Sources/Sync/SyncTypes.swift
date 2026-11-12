public struct SkippedFIT: Sendable, Equatable {
    public let activityId: Int64
    public let description: String

    public init(activityId: Int64, description: String) {
        self.activityId = activityId
        self.description = description
    }
}
