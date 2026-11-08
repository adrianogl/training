import TrainingCore

public struct HRVSummaryDTO: Decodable, Equatable, Sendable {
    public var day: Day
    public var lastNightAvg: Double?
    public var weeklyAvg: Double?
    public var status: String?
    public var baselineLowUpper: Double?
    public var baselineBalancedLow: Double?
    public var baselineBalancedUpper: Double?

    public init(
        day: Day,
        lastNightAvg: Double? = nil,
        weeklyAvg: Double? = nil,
        status: String? = nil,
        baselineLowUpper: Double? = nil,
        baselineBalancedLow: Double? = nil,
        baselineBalancedUpper: Double? = nil
    ) {
        self.day = day
        self.lastNightAvg = lastNightAvg
        self.weeklyAvg = weeklyAvg
        self.status = status
        self.baselineLowUpper = baselineLowUpper
        self.baselineBalancedLow = baselineBalancedLow
        self.baselineBalancedUpper = baselineBalancedUpper
    }

    private enum CodingKeys: String, CodingKey {
        case calendarDate, lastNightAvg, weeklyAvg, status, baseline
    }

    private struct Baseline: Decodable {
        var lowUpper: Double?
        var balancedLow: Double?
        var balancedUpper: Double?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Day.self, forKey: .calendarDate)
        lastNightAvg = try c.decodeIfPresent(Double.self, forKey: .lastNightAvg)
        weeklyAvg = try c.decodeIfPresent(Double.self, forKey: .weeklyAvg)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        let baseline = try c.decodeIfPresent(Baseline.self, forKey: .baseline)
        baselineLowUpper = baseline?.lowUpper
        baselineBalancedLow = baseline?.balancedLow
        baselineBalancedUpper = baseline?.balancedUpper
    }
}
