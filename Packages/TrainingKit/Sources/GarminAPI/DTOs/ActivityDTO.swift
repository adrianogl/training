public struct ActivityDTO: Decodable, Equatable, Sendable {
    public var activityId: Int64
    public var activityName: String?
    public var typeKey: String?
    public var startTimeLocal: String?
    public var locationName: String?
    public var distance: Double?
    public var duration: Double?
    public var movingDuration: Double?
    public var trainingEffectLabel: String?
    public var averageHR: Double?
    public var maxHR: Double?
    public var activityTrainingLoad: Double?
    public var aerobicTrainingEffect: Double?
    public var anaerobicTrainingEffect: Double?
    public var averageRunningCadenceInStepsPerMinute: Double?
    public var avgGroundContactTime: Double?
    public var avgVerticalOscillation: Double?
    public var avgVerticalRatio: Double?
    public var avgStrideLength: Double?
    public var avgPower: Double?
    public var elevationGain: Double?
    public var elevationLoss: Double?
    public var fastestSplit_1000: Double?
    public var fastestSplit_5000: Double?
    public var hrTimeInZone: [Double]?
    public var pr: Bool?

    public init(
        activityId: Int64,
        activityName: String? = nil,
        typeKey: String? = nil,
        startTimeLocal: String? = nil,
        locationName: String? = nil,
        distance: Double? = nil,
        duration: Double? = nil,
        movingDuration: Double? = nil,
        trainingEffectLabel: String? = nil,
        averageHR: Double? = nil,
        maxHR: Double? = nil,
        activityTrainingLoad: Double? = nil,
        aerobicTrainingEffect: Double? = nil,
        anaerobicTrainingEffect: Double? = nil,
        averageRunningCadenceInStepsPerMinute: Double? = nil,
        avgGroundContactTime: Double? = nil,
        avgVerticalOscillation: Double? = nil,
        avgVerticalRatio: Double? = nil,
        avgStrideLength: Double? = nil,
        avgPower: Double? = nil,
        elevationGain: Double? = nil,
        elevationLoss: Double? = nil,
        fastestSplit_1000: Double? = nil,
        fastestSplit_5000: Double? = nil,
        hrTimeInZone: [Double]? = nil,
        pr: Bool? = nil
    ) {
        self.activityId = activityId
        self.activityName = activityName
        self.typeKey = typeKey
        self.startTimeLocal = startTimeLocal
        self.locationName = locationName
        self.distance = distance
        self.duration = duration
        self.movingDuration = movingDuration
        self.trainingEffectLabel = trainingEffectLabel
        self.averageHR = averageHR
        self.maxHR = maxHR
        self.activityTrainingLoad = activityTrainingLoad
        self.aerobicTrainingEffect = aerobicTrainingEffect
        self.anaerobicTrainingEffect = anaerobicTrainingEffect
        self.averageRunningCadenceInStepsPerMinute = averageRunningCadenceInStepsPerMinute
        self.avgGroundContactTime = avgGroundContactTime
        self.avgVerticalOscillation = avgVerticalOscillation
        self.avgVerticalRatio = avgVerticalRatio
        self.avgStrideLength = avgStrideLength
        self.avgPower = avgPower
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.fastestSplit_1000 = fastestSplit_1000
        self.fastestSplit_5000 = fastestSplit_5000
        self.hrTimeInZone = hrTimeInZone
        self.pr = pr
    }

    private enum CodingKeys: String, CodingKey {
        case activityId, activityName, activityType, startTimeLocal, locationName
        case distance, duration, movingDuration, trainingEffectLabel, averageHR, maxHR, activityTrainingLoad, aerobicTrainingEffect, anaerobicTrainingEffect, averageRunningCadenceInStepsPerMinute, avgGroundContactTime, avgVerticalOscillation, avgVerticalRatio, avgStrideLength, avgPower, elevationGain, elevationLoss, fastestSplit_1000, fastestSplit_5000, pr
        case hrTimeInZone_1, hrTimeInZone_2, hrTimeInZone_3, hrTimeInZone_4, hrTimeInZone_5
    }

    private struct ActivityType: Decodable { var typeKey: String? }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activityId = try c.decode(Int64.self, forKey: .activityId)
        activityName = try c.decodeIfPresent(String.self, forKey: .activityName)
        typeKey = try c.decodeIfPresent(ActivityType.self, forKey: .activityType)?.typeKey
        startTimeLocal = try c.decodeIfPresent(String.self, forKey: .startTimeLocal)
        locationName = try c.decodeIfPresent(String.self, forKey: .locationName)
        distance = try c.decodeIfPresent(Double.self, forKey: .distance)
        duration = try c.decodeIfPresent(Double.self, forKey: .duration)
        movingDuration = try c.decodeIfPresent(Double.self, forKey: .movingDuration)
        trainingEffectLabel = try c.decodeIfPresent(String.self, forKey: .trainingEffectLabel)
        averageHR = try c.decodeIfPresent(Double.self, forKey: .averageHR)
        maxHR = try c.decodeIfPresent(Double.self, forKey: .maxHR)
        activityTrainingLoad = try c.decodeIfPresent(Double.self, forKey: .activityTrainingLoad)
        aerobicTrainingEffect = try c.decodeIfPresent(Double.self, forKey: .aerobicTrainingEffect)
        anaerobicTrainingEffect = try c.decodeIfPresent(Double.self, forKey: .anaerobicTrainingEffect)
        averageRunningCadenceInStepsPerMinute = try c.decodeIfPresent(Double.self, forKey: .averageRunningCadenceInStepsPerMinute)
        avgGroundContactTime = try c.decodeIfPresent(Double.self, forKey: .avgGroundContactTime)
        avgVerticalOscillation = try c.decodeIfPresent(Double.self, forKey: .avgVerticalOscillation)
        avgVerticalRatio = try c.decodeIfPresent(Double.self, forKey: .avgVerticalRatio)
        avgStrideLength = try c.decodeIfPresent(Double.self, forKey: .avgStrideLength)
        avgPower = try c.decodeIfPresent(Double.self, forKey: .avgPower)
        elevationGain = try c.decodeIfPresent(Double.self, forKey: .elevationGain)
        elevationLoss = try c.decodeIfPresent(Double.self, forKey: .elevationLoss)
        fastestSplit_1000 = try c.decodeIfPresent(Double.self, forKey: .fastestSplit_1000)
        fastestSplit_5000 = try c.decodeIfPresent(Double.self, forKey: .fastestSplit_5000)
        pr = try c.decodeIfPresent(Bool.self, forKey: .pr)
        let zoneKeys: [CodingKeys] = [.hrTimeInZone_1, .hrTimeInZone_2, .hrTimeInZone_3, .hrTimeInZone_4, .hrTimeInZone_5]
        let zones = try zoneKeys.map { try c.decodeIfPresent(Double.self, forKey: $0) }
        hrTimeInZone = zones.contains { $0 != nil } ? zones.map { $0 ?? 0 } : nil
    }
}
