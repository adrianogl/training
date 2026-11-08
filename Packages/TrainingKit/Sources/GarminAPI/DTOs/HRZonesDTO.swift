public struct HRZonesDTO: Decodable, Equatable, Sendable {
    public var sport: String?
    public var zone1Floor: Int?
    public var zone2Floor: Int?
    public var zone3Floor: Int?
    public var zone4Floor: Int?
    public var zone5Floor: Int?
    public var maxHeartRateUsed: Int?
    public var lactateThresholdHeartRateUsed: Int?
    public var restingHeartRateUsed: Int?

    public init(
        sport: String? = nil,
        zone1Floor: Int? = nil,
        zone2Floor: Int? = nil,
        zone3Floor: Int? = nil,
        zone4Floor: Int? = nil,
        zone5Floor: Int? = nil,
        maxHeartRateUsed: Int? = nil,
        lactateThresholdHeartRateUsed: Int? = nil,
        restingHeartRateUsed: Int? = nil
    ) {
        self.sport = sport
        self.zone1Floor = zone1Floor
        self.zone2Floor = zone2Floor
        self.zone3Floor = zone3Floor
        self.zone4Floor = zone4Floor
        self.zone5Floor = zone5Floor
        self.maxHeartRateUsed = maxHeartRateUsed
        self.lactateThresholdHeartRateUsed = lactateThresholdHeartRateUsed
        self.restingHeartRateUsed = restingHeartRateUsed
    }

    private enum CodingKeys: String, CodingKey {
        case sport, zone1Floor, zone2Floor, zone3Floor, zone4Floor, zone5Floor
        case maxHeartRateUsed, lactateThresholdHeartRateUsed, restingHeartRateUsed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sport = try c.decodeIfPresent(String.self, forKey: .sport)
        zone1Floor = try c.decodeRoundedInt(forKey: .zone1Floor)
        zone2Floor = try c.decodeRoundedInt(forKey: .zone2Floor)
        zone3Floor = try c.decodeRoundedInt(forKey: .zone3Floor)
        zone4Floor = try c.decodeRoundedInt(forKey: .zone4Floor)
        zone5Floor = try c.decodeRoundedInt(forKey: .zone5Floor)
        maxHeartRateUsed = try c.decodeRoundedInt(forKey: .maxHeartRateUsed)
        lactateThresholdHeartRateUsed = try c.decodeRoundedInt(forKey: .lactateThresholdHeartRateUsed)
        restingHeartRateUsed = try c.decodeRoundedInt(forKey: .restingHeartRateUsed)
    }
}
