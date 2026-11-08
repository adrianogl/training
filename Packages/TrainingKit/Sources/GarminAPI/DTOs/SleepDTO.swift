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
        struct Overall: Decodable { var value: LenientInt? }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Day.self, forKey: .calendarDate)
        sleepTimeSeconds = try c.decodeRoundedInt(forKey: .sleepTimeSeconds)
        deepSleepSeconds = try c.decodeRoundedInt(forKey: .deepSleepSeconds)
        lightSleepSeconds = try c.decodeRoundedInt(forKey: .lightSleepSeconds)
        remSleepSeconds = try c.decodeRoundedInt(forKey: .remSleepSeconds)
        awakeSleepSeconds = try c.decodeRoundedInt(forKey: .awakeSleepSeconds)
        sleepEndTimestampGMT = try c.decodeRoundedInt(forKey: .sleepEndTimestampGMT).map(Int64.init)
        sleepEndTimestampLocal = try c.decodeRoundedInt(forKey: .sleepEndTimestampLocal).map(Int64.init)
        overallScore = try c.decodeIfPresent(Scores.self, forKey: .sleepScores)?.overall?.value?.value
    }
}
