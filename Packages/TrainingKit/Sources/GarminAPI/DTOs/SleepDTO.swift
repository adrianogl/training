import TrainingCore

public struct SleepDTO: Decodable, Equatable, Sendable {
    public var day: Day
    public var sleepTimeSeconds: Int?
    public var deepSleepSeconds: Int?
    public var lightSleepSeconds: Int?
    public var remSleepSeconds: Int?
    public var awakeSleepSeconds: Int?
    public var overallScore: Int?
    public var sleepEndTimestampLocal: Int64?
    public var sleepEndTimestampGMT: Int64?

    public init(
        day: Day,
        sleepTimeSeconds: Int? = nil,
        deepSleepSeconds: Int? = nil,
        lightSleepSeconds: Int? = nil,
        remSleepSeconds: Int? = nil,
        awakeSleepSeconds: Int? = nil,
        overallScore: Int? = nil,
        sleepEndTimestampLocal: Int64? = nil,
        sleepEndTimestampGMT: Int64? = nil
    ) {
        self.day = day
        self.sleepTimeSeconds = sleepTimeSeconds
        self.deepSleepSeconds = deepSleepSeconds
        self.lightSleepSeconds = lightSleepSeconds
        self.remSleepSeconds = remSleepSeconds
        self.awakeSleepSeconds = awakeSleepSeconds
        self.overallScore = overallScore
        self.sleepEndTimestampLocal = sleepEndTimestampLocal
        self.sleepEndTimestampGMT = sleepEndTimestampGMT
    }

    private enum CodingKeys: String, CodingKey {
        case calendarDate, sleepTimeSeconds, deepSleepSeconds, lightSleepSeconds, remSleepSeconds
        case awakeSleepSeconds, sleepEndTimestampGMT, sleepEndTimestampLocal, sleepScores
    }

    private struct Scores: Decodable {
        var overall: Overall?
        struct Overall: Decodable { var value: Int? }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Day.self, forKey: .calendarDate)
        sleepTimeSeconds = try c.decodeIfPresent(Int.self, forKey: .sleepTimeSeconds)
        deepSleepSeconds = try c.decodeIfPresent(Int.self, forKey: .deepSleepSeconds)
        lightSleepSeconds = try c.decodeIfPresent(Int.self, forKey: .lightSleepSeconds)
        remSleepSeconds = try c.decodeIfPresent(Int.self, forKey: .remSleepSeconds)
        awakeSleepSeconds = try c.decodeIfPresent(Int.self, forKey: .awakeSleepSeconds)
        sleepEndTimestampGMT = try c.decodeIfPresent(Int64.self, forKey: .sleepEndTimestampGMT)
        sleepEndTimestampLocal = try c.decodeIfPresent(Int64.self, forKey: .sleepEndTimestampLocal)
        overallScore = try c.decodeIfPresent(Scores.self, forKey: .sleepScores)?.overall?.value
    }
}
