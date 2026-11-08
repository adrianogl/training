public struct WorkoutNarrative: Codable, Sendable, Equatable {
    public var findings: [String]
    public var evolution: String?
    public var generatedBy: String
    public var factsKey: String

    public init(findings: [String], evolution: String?, generatedBy: String, factsKey: String) {
        self.findings = findings
        self.evolution = evolution
        self.generatedBy = generatedBy
        self.factsKey = factsKey
    }
}

public struct EvolutionFacts: Sendable, Equatable {
    public var paceDelta: Double
    public var heartRateDelta: Double?
    public var oldestDate: String

    public init(paceDelta: Double, heartRateDelta: Double?, oldestDate: String) {
        self.paceDelta = paceDelta
        self.heartRateDelta = heartRateDelta
        self.oldestDate = oldestDate
    }
}

public struct GeneratedNarrative: Sendable, Equatable {
    public var findings: [String]
    public var evolution: String

    public init(findings: [String], evolution: String) {
        self.findings = findings
        self.evolution = evolution
    }
}

struct EvolutionParts {
    var pace: String
    var heartRate: String?
    var since: String
}
