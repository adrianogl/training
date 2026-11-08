public enum StepIntensity: String, Codable, Sendable, Equatable {
    case warmup, active, recovery, cooldown, rest, other
}

public enum StepDuration: Codable, Sendable, Equatable {
    case distance(meters: Double)
    case time(seconds: Double)
    case open
    case repeatSteps(fromIndex: Int, count: Int)
}

public enum StepTarget: Codable, Sendable, Equatable {
    case open
    case speed(low: Double, high: Double)
    case heartRateBpm(low: Int, high: Int)
    case heartRatePercentMax(low: Int, high: Int)
    case heartRateZone(Int)
}

public struct PrescribedStep: Codable, Sendable, Equatable {
    public var index: Int
    public var intensity: StepIntensity
    public var duration: StepDuration
    public var target: StepTarget

    public init(index: Int, intensity: StepIntensity, duration: StepDuration, target: StepTarget) {
        self.index = index
        self.intensity = intensity
        self.duration = duration
        self.target = target
    }
}

public struct WorkoutPrescription: Codable, Sendable, Equatable {
    public var name: String?
    public var description: String?
    public var steps: [PrescribedStep]

    public init(name: String? = nil, description: String? = nil, steps: [PrescribedStep] = []) {
        self.name = name
        self.description = description
        self.steps = steps
    }
}

public struct LapSummary: Codable, Sendable, Equatable {
    public var stepIndex: Int?
    public var intensity: StepIntensity?
    public var trigger: String?
    public var startOffset: Double
    public var timerSeconds: Double
    public var distance: Double
    public var avgSpeed: Double?
    public var avgHeartRate: Int?
    public var maxHeartRate: Int?

    public init(
        stepIndex: Int? = nil,
        intensity: StepIntensity? = nil,
        trigger: String? = nil,
        startOffset: Double,
        timerSeconds: Double,
        distance: Double,
        avgSpeed: Double? = nil,
        avgHeartRate: Int? = nil,
        maxHeartRate: Int? = nil
    ) {
        self.stepIndex = stepIndex
        self.intensity = intensity
        self.trigger = trigger
        self.startOffset = startOffset
        self.timerSeconds = timerSeconds
        self.distance = distance
        self.avgSpeed = avgSpeed
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
    }
}

public struct WorkoutStructure: Codable, Sendable, Equatable {
    public var prescription: WorkoutPrescription?
    public var laps: [LapSummary]

    public init(prescription: WorkoutPrescription? = nil, laps: [LapSummary] = []) {
        self.prescription = prescription
        self.laps = laps
    }
}
