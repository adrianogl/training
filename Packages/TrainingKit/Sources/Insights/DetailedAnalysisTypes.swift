import Foundation
import WorkoutAnalysis

public enum DetailedFindingKind: String, Sendable, Equatable, CaseIterable {
    case completion, fadeKm, hrDrift, startPace, readiness, weekLoad, hrAtPace, pauses, repsConsistency, goal
}

public enum DetailedTone: Sendable, Equatable {
    case fix, good, info
}

public struct DetailedEvidence: Sendable, Equatable {
    public var key: String
    public var value: Double

    public init(key: String, value: Double) {
        self.key = key
        self.value = value
    }
}

public struct DetailedFinding: Sendable, Equatable, Identifiable {
    public var kind: DetailedFindingKind
    public var tone: DetailedTone
    public var title: String
    public var text: String
    public var evidence: [DetailedEvidence]

    public var id: DetailedFindingKind { kind }

    public init(kind: DetailedFindingKind, tone: DetailedTone, title: String, text: String, evidence: [DetailedEvidence]) {
        self.kind = kind
        self.tone = tone
        self.title = title
        self.text = text
        self.evidence = evidence
    }

    public func value(_ key: String) -> Double? {
        evidence.first { $0.key == key }?.value
    }
}

public struct DetailedSplit: Sendable, Equatable, Identifiable {
    public var km: Int
    public var paceSeconds: Double
    public var heartRate: Double?

    public var id: Int { km }

    public init(km: Int, paceSeconds: Double, heartRate: Double?) {
        self.km = km
        self.paceSeconds = paceSeconds
        self.heartRate = heartRate
    }
}

public struct DetailedRunPoint: Sendable, Equatable, Identifiable {
    public var activityId: Int64
    public var start: Date
    public var percentOfDistance: Double?
    public var fadeKm: Int?
    public var isComplete: Bool
    public var pauseCount: Int?

    public var id: Int64 { activityId }
    public var isClean: Bool { isComplete && pauseCount == 0 }

    public init(activityId: Int64, start: Date, percentOfDistance: Double?, fadeKm: Int?, isComplete: Bool, pauseCount: Int?) {
        self.activityId = activityId
        self.start = start
        self.percentOfDistance = percentOfDistance
        self.fadeKm = fadeKm
        self.isComplete = isComplete
        self.pauseCount = pauseCount
    }
}

public struct DetailedKPIs: Sendable, Equatable {
    public var completionPercent: Double?
    public var completionAverage: Double?
    public var fadeKm: Int?
    public var fadeKmAverage: Double?
    public var driftPercent: Double?
    public var driftAverage: Double?

    public init(
        completionPercent: Double? = nil, completionAverage: Double? = nil,
        fadeKm: Int? = nil, fadeKmAverage: Double? = nil,
        driftPercent: Double? = nil, driftAverage: Double? = nil
    ) {
        self.completionPercent = completionPercent
        self.completionAverage = completionAverage
        self.fadeKm = fadeKm
        self.fadeKmAverage = fadeKmAverage
        self.driftPercent = driftPercent
        self.driftAverage = driftAverage
    }
}

public enum DetailedRecommendationKind: String, Sendable, Equatable {
    case startPace, fuel, swapDay, easeWeek
}

public struct DetailedRecommendation: Sendable, Equatable, Identifiable {
    public var kind: DetailedRecommendationKind
    public var title: String
    public var reason: String
    public var number: Double

    public var id: DetailedRecommendationKind { kind }

    public init(kind: DetailedRecommendationKind, title: String, reason: String, number: Double) {
        self.kind = kind
        self.title = title
        self.reason = reason
        self.number = number
    }
}

public struct DetailedGoalNote: Sendable, Equatable {
    public var title: String
    public var status: String
    public var isMet: Bool
    public var lines: [String]

    public init(title: String, status: String, isMet: Bool, lines: [String]) {
        self.title = title
        self.status = status
        self.isMet = isMet
        self.lines = lines
    }
}

public struct DetailedAnalysis: Sendable, Equatable {
    public var kind: RunKind
    public var kpis: DetailedKPIs
    public var splits: [DetailedSplit]
    public var fadeKm: Int?
    public var pauseKilometers: [Double]
    public var current: DetailedRunPoint
    public var similar: [DetailedRunPoint]
    public var windowDays: Int
    public var readinessDays: Int
    public var findings: [DetailedFinding]
    public var recommendations: [DetailedRecommendation]

    public func finding(_ kind: DetailedFindingKind) -> DetailedFinding? {
        findings.first { $0.kind == kind }
    }
}
