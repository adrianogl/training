public struct HeartRateZones: Sendable, Equatable {
    public var floors: [Int]
    public var maxHeartRate: Int?

    public init(floors: [Int], maxHeartRate: Int? = nil) {
        self.floors = floors
        self.maxHeartRate = maxHeartRate
    }
}
