import TrainingCore

public struct DailySummaryDTO: Decodable, Equatable, Sendable {
    public var day: Day
    public var restingHeartRate: Int?
    public var avgStress: Int?
    public var bodyBatteryMin: Int?
    public var bodyBatteryMax: Int?
    public var avgRespiration: Double?
    public var moderateIntensityMinutes: Int?
    public var vigorousIntensityMinutes: Int?

    public init(
        day: Day,
        restingHeartRate: Int? = nil,
        avgStress: Int? = nil,
        bodyBatteryMin: Int? = nil,
        bodyBatteryMax: Int? = nil,
        avgRespiration: Double? = nil,
        moderateIntensityMinutes: Int? = nil,
        vigorousIntensityMinutes: Int? = nil
    ) {
        self.day = day
        self.restingHeartRate = restingHeartRate
        self.avgStress = avgStress
        self.bodyBatteryMin = bodyBatteryMin
        self.bodyBatteryMax = bodyBatteryMax
        self.avgRespiration = avgRespiration
        self.moderateIntensityMinutes = moderateIntensityMinutes
        self.vigorousIntensityMinutes = vigorousIntensityMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case calendarDate, heartRate, stress, bodyBattery, respiration, intensityMinutes
    }

    private struct HeartRate: Decodable { var restingValue: Int? }
    private struct Stress: Decodable { var avgLevel: Int? }
    private struct BodyBattery: Decodable { var minValue: Int?; var maxValue: Int? }
    private struct Respiration: Decodable { var avgValue: Double? }
    private struct IntensityMinutes: Decodable { var moderate: Int?; var vigorous: Int? }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(Day.self, forKey: .calendarDate)
        restingHeartRate = try c.decodeIfPresent(HeartRate.self, forKey: .heartRate)?.restingValue
        avgStress = try c.decodeIfPresent(Stress.self, forKey: .stress)?.avgLevel
        let battery = try c.decodeIfPresent(BodyBattery.self, forKey: .bodyBattery)
        bodyBatteryMin = battery?.minValue
        bodyBatteryMax = battery?.maxValue
        avgRespiration = try c.decodeIfPresent(Respiration.self, forKey: .respiration)?.avgValue
        let intensity = try c.decodeIfPresent(IntensityMinutes.self, forKey: .intensityMinutes)
        moderateIntensityMinutes = intensity?.moderate
        vigorousIntensityMinutes = intensity?.vigorous
    }
}
