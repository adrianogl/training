public struct HRZoneProfile: Codable, Equatable, Sendable {
    public var trainingMethod: String?
    public var restingHeartRateUsed: Int?
    public var lactateThresholdHeartRateUsed: Int?
    public var zone1Floor: Int?
    public var zone2Floor: Int?
    public var zone3Floor: Int?
    public var zone4Floor: Int?
    public var zone5Floor: Int?
    public var maxHeartRateUsed: Int?
    public var restingHrAutoUpdateUsed: Bool?
    public var sport: String?
    public var changeState: String?

    public init(
        trainingMethod: String? = nil, restingHeartRateUsed: Int? = nil, lactateThresholdHeartRateUsed: Int? = nil,
        zone1Floor: Int? = nil, zone2Floor: Int? = nil, zone3Floor: Int? = nil, zone4Floor: Int? = nil, zone5Floor: Int? = nil,
        maxHeartRateUsed: Int? = nil, restingHrAutoUpdateUsed: Bool? = nil, sport: String? = nil, changeState: String? = nil
    ) {
        self.trainingMethod = trainingMethod
        self.restingHeartRateUsed = restingHeartRateUsed
        self.lactateThresholdHeartRateUsed = lactateThresholdHeartRateUsed
        self.zone1Floor = zone1Floor
        self.zone2Floor = zone2Floor
        self.zone3Floor = zone3Floor
        self.zone4Floor = zone4Floor
        self.zone5Floor = zone5Floor
        self.maxHeartRateUsed = maxHeartRateUsed
        self.restingHrAutoUpdateUsed = restingHrAutoUpdateUsed
        self.sport = sport
        self.changeState = changeState
    }

    public var upperFloors: [Int?] { [zone2Floor, zone3Floor, zone4Floor, zone5Floor] }
}
