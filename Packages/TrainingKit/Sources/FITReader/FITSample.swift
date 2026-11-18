public struct FITSample: Codable, Sendable, Equatable {
    public var t: Double
    public var heartRate: Int?
    public var speed: Double?
    public var altitude: Double?
    public var distance: Double?
    public var cadence: Double?
    public var stanceTime: Double?
    public var lat: Double?
    public var lon: Double?

    public init(
        t: Double, heartRate: Int? = nil, speed: Double? = nil, altitude: Double? = nil, distance: Double? = nil,
        cadence: Double? = nil, stanceTime: Double? = nil, lat: Double? = nil, lon: Double? = nil
    ) {
        self.t = t
        self.heartRate = heartRate
        self.speed = speed
        self.altitude = altitude
        self.distance = distance
        self.cadence = cadence
        self.stanceTime = stanceTime
        self.lat = lat
        self.lon = lon
    }
}
