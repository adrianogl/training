public struct SyncReport: Sendable, Equatable {
    public var dailyUpserted: Int
    public var activitiesUpserted: Int
    public var fitProcessed: Int
    public var duplicatesRemoved: Int

    public init(dailyUpserted: Int = 0, activitiesUpserted: Int = 0, fitProcessed: Int = 0, duplicatesRemoved: Int = 0) {
        self.dailyUpserted = dailyUpserted
        self.activitiesUpserted = activitiesUpserted
        self.fitProcessed = fitProcessed
        self.duplicatesRemoved = duplicatesRemoved
    }
}
