import Projections
import TrainingCore

public enum MetricKind: String, CaseIterable, Sendable {
    case vo2max, zone2Pace, fitness, monthlyVolume, loadFocus, thresholdPace, thresholdHeartRate
    case prediction5k, prediction10k, predictionHalf, predictionFull
    case durability, hillStrength, cadence, groundContact, verticalOscillation
    case restingHeartRate, hrv, sleep, bodyBattery, zoneDistribution
}

public enum MetricPeriod: String, CaseIterable, Sendable {
    case sixMonths, oneYear, twoYears, all

    var days: Int? {
        InsightsConstants.periodDays[self]
    }
}

public struct MetricStats: Sendable, Equatable {
    public var current: Double?
    public var average: Double?
    public var minimum: Double?
    public var maximum: Double?
    public var change: Double?

    public init(current: Double?, average: Double?, minimum: Double?, maximum: Double?, change: Double?) {
        self.current = current
        self.average = average
        self.minimum = minimum
        self.maximum = maximum
        self.change = change
    }
}

public struct MetricSeries: Sendable {
    public var kind: MetricKind
    public var points: [(Day, Double)]
    public var movingAverage7: [(Day, Double)]
    public var normalBand: ClosedRange<Double>?
    public var projection: [ProjectionPoint]
    public var raceDayValue: Double?
    public var stats: MetricStats
    public var monthly: [(Day, Double)]
    public var lastYear: [(Day, Double)]
    public var reading: String

    public init(
        kind: MetricKind,
        points: [(Day, Double)],
        movingAverage7: [(Day, Double)],
        normalBand: ClosedRange<Double>?,
        projection: [ProjectionPoint],
        raceDayValue: Double?,
        stats: MetricStats,
        monthly: [(Day, Double)],
        lastYear: [(Day, Double)],
        reading: String
    ) {
        self.kind = kind
        self.points = points
        self.movingAverage7 = movingAverage7
        self.normalBand = normalBand
        self.projection = projection
        self.raceDayValue = raceDayValue
        self.stats = stats
        self.monthly = monthly
        self.lastYear = lastYear
        self.reading = reading
    }
}

enum MetricFormat {
    case pace
    case duration
    case number(decimals: Int, unit: String)
}

struct RawMetric {
    var values: [(Day, Double)]
    var normalBand: ClosedRange<Double>?
}
