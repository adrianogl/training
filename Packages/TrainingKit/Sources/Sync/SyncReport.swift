public struct SyncReport: Sendable, Equatable {
    public var dailyUpserted: Int
    public var activitiesUpserted: Int
    public var fitProcessed: Int
    public var reprocessed: Int
    public var fitStoppedByRateLimit: Bool
    public var stoppedByRateLimit: Bool
    public var duplicatesRemoved: Int
    public var processedActivityIds: Set<Int64>

    public init(
        dailyUpserted: Int = 0,
        activitiesUpserted: Int = 0,
        fitProcessed: Int = 0,
        reprocessed: Int = 0,
        fitStoppedByRateLimit: Bool = false,
        stoppedByRateLimit: Bool = false,
        duplicatesRemoved: Int = 0,
        processedActivityIds: Set<Int64> = []
    ) {
        self.dailyUpserted = dailyUpserted
        self.activitiesUpserted = activitiesUpserted
        self.fitProcessed = fitProcessed
        self.reprocessed = reprocessed
        self.fitStoppedByRateLimit = fitStoppedByRateLimit
        self.stoppedByRateLimit = stoppedByRateLimit
        self.duplicatesRemoved = duplicatesRemoved
        self.processedActivityIds = processedActivityIds
    }
}
