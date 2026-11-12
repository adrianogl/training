public struct HeartRateZoneInfo: Codable, Sendable, Equatable {
    public var thresholdHeartRate: Int?
    public var maxHeartRate: Int?
    public var restingHeartRate: Int?
    public var calcType: Int?
    public var floors: [Int]

    public init(thresholdHeartRate: Int? = nil, maxHeartRate: Int? = nil, restingHeartRate: Int? = nil, calcType: Int? = nil, floors: [Int] = []) {
        self.thresholdHeartRate = thresholdHeartRate
        self.maxHeartRate = maxHeartRate
        self.restingHeartRate = restingHeartRate
        self.calcType = calcType
        self.floors = floors
    }
}
