public struct PhysioMetrics: Codable, Sendable, Equatable {
    public var vo2max: Double?
    public var recoveryMinutes: Int?
    public var performanceCondition: Int?

    public init(vo2max: Double? = nil, recoveryMinutes: Int? = nil, performanceCondition: Int? = nil) {
        self.vo2max = vo2max
        self.recoveryMinutes = recoveryMinutes
        self.performanceCondition = performanceCondition
    }
}
