public struct FITSample: Codable, Sendable, Equatable {
    public var t: Double
    public var heartRate: Int?
    public var speed: Double?
    public var altitude: Double?
    public var distance: Double?

    public init(t: Double, heartRate: Int? = nil, speed: Double? = nil, altitude: Double? = nil, distance: Double? = nil) {
        self.t = t
        self.heartRate = heartRate
        self.speed = speed
        self.altitude = altitude
        self.distance = distance
    }
}
