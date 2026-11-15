import Foundation
import TrainingCore

public enum TrainerDayKind: String, Codable, Sendable, CaseIterable {
    case easy
    case threshold
    case vo2max
    case optionalEasy
    case long
    case off
    case race
}

public enum TrainerPhase: String, Codable, Sendable, CaseIterable {
    case base
    case build
    case specific
    case taper
}

public enum TrainerStepKind: String, Codable, Sendable {
    case warmup
    case work
    case recovery
    case cooldown
    case steady
}

public struct TrainerStep: Codable, Sendable, Equatable {
    public var kind: TrainerStepKind
    public var repeats: Int
    public var meters: Double
    public var paceLow: Double?
    public var paceHigh: Double?

    public init(kind: TrainerStepKind, repeats: Int = 1, meters: Double, paceLow: Double? = nil, paceHigh: Double? = nil) {
        self.kind = kind
        self.repeats = repeats
        self.meters = meters
        self.paceLow = paceLow
        self.paceHigh = paceHigh
    }
}

public struct TrainerWorkout: Codable, Sendable, Equatable, Identifiable {
    public var day: Day
    public var kind: TrainerDayKind
    public var title: String
    public var totalMeters: Double
    public var steps: [TrainerStep]
    public var paceLow: Double?
    public var paceHigh: Double?
    public var note: String?
    public var rationale: String

    public var id: String { day.iso }

    public init(day: Day, kind: TrainerDayKind, title: String, totalMeters: Double, steps: [TrainerStep], paceLow: Double? = nil, paceHigh: Double? = nil, note: String? = nil, rationale: String) {
        self.day = day
        self.kind = kind
        self.title = title
        self.totalMeters = totalMeters
        self.steps = steps
        self.paceLow = paceLow
        self.paceHigh = paceHigh
        self.note = note
        self.rationale = rationale
    }
}

public struct TrainerWeek: Codable, Sendable, Equatable, Identifiable {
    public var index: Int
    public var start: Day
    public var phase: TrainerPhase
    public var isRecovery: Bool
    public var plannedMeters: Double
    public var targetMeters: Double
    public var longMeters: Double
    public var thresholdFocus: String
    public var vo2Focus: String

    public var id: Int { index }

    public init(index: Int, start: Day, phase: TrainerPhase, isRecovery: Bool, plannedMeters: Double, targetMeters: Double? = nil, longMeters: Double, thresholdFocus: String, vo2Focus: String) {
        self.index = index
        self.start = start
        self.phase = phase
        self.isRecovery = isRecovery
        self.plannedMeters = plannedMeters
        self.targetMeters = targetMeters ?? plannedMeters
        self.longMeters = longMeters
        self.thresholdFocus = thresholdFocus
        self.vo2Focus = vo2Focus
    }

    private enum CodingKeys: String, CodingKey {
        case index, start, phase, isRecovery, plannedMeters, targetMeters, longMeters, thresholdFocus, vo2Focus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let planned = try container.decode(Double.self, forKey: .plannedMeters)
        self.init(
            index: try container.decode(Int.self, forKey: .index),
            start: try container.decode(Day.self, forKey: .start),
            phase: try container.decode(TrainerPhase.self, forKey: .phase),
            isRecovery: try container.decode(Bool.self, forKey: .isRecovery),
            plannedMeters: planned,
            targetMeters: try container.decodeIfPresent(Double.self, forKey: .targetMeters),
            longMeters: try container.decode(Double.self, forKey: .longMeters),
            thresholdFocus: try container.decode(String.self, forKey: .thresholdFocus),
            vo2Focus: try container.decode(String.self, forKey: .vo2Focus)
        )
    }
}

public enum TrainerStrengthGroup: String, Codable, Sendable, CaseIterable {
    case upper
    case lower
    case fullBody
    case core
}

public enum TrainerStrengthLoad: String, Codable, Sendable, CaseIterable {
    case light
    case heavy
}

public struct TrainerStrengthSession: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var weekday: Int
    public var group: TrainerStrengthGroup
    public var legLoad: TrainerStrengthLoad
    public var name: String

    public init(id: UUID = UUID(), weekday: Int, group: TrainerStrengthGroup, legLoad: TrainerStrengthLoad, name: String) {
        self.id = id
        self.weekday = weekday
        self.group = group
        self.legLoad = legLoad
        self.name = name
    }
}

public struct TrainerStrengthDone: Sendable, Equatable {
    public var activityId: Int64
    public var day: Day
    public var name: String
    public var seconds: Double

    public init(activityId: Int64, day: Day, name: String, seconds: Double) {
        self.activityId = activityId
        self.day = day
        self.name = name
        self.seconds = seconds
    }
}

public enum TrainerTargetKind: String, Codable, Sendable {
    case race
    case text
}

public struct TrainerTarget: Codable, Sendable, Equatable {
    public var kind: TrainerTargetKind
    public var name: String
    public var raceId: UUID?
    public var date: Day?
    public var distanceMeters: Double?
    public var goalSeconds: Double?
    public var text: String?

    public init(kind: TrainerTargetKind, name: String, raceId: UUID? = nil, date: Day? = nil, distanceMeters: Double? = nil, goalSeconds: Double? = nil, text: String? = nil) {
        self.kind = kind
        self.name = name
        self.raceId = raceId
        self.date = date
        self.distanceMeters = distanceMeters
        self.goalSeconds = goalSeconds
        self.text = text
    }
}

public struct TrainerPaces: Codable, Sendable, Equatable {
    public var easy: Double
    public var long: Double
    public var threshold: Double
    public var vo2max: Double
    public var race: Double?
    public var easyRuns: Int
    public var thresholdRuns: Int
    public var vo2Runs: Int

    public init(easy: Double, long: Double, threshold: Double, vo2max: Double, race: Double? = nil, easyRuns: Int = 0, thresholdRuns: Int = 0, vo2Runs: Int = 0) {
        self.easy = easy
        self.long = long
        self.threshold = threshold
        self.vo2max = vo2max
        self.race = race
        self.easyRuns = easyRuns
        self.thresholdRuns = thresholdRuns
        self.vo2Runs = vo2Runs
    }
}

public enum TrainerRequestCategory: String, Codable, Sendable, CaseIterable {
    case travel
    case pain
    case fatigue
    case moreTime
    case goalChanged
    case other
}

public struct TrainerRequest: Codable, Sendable, Equatable {
    public var category: TrainerRequestCategory
    public var text: String
    public var from: Day
    public var until: Day?

    public init(category: TrainerRequestCategory, text: String, from: Day, until: Day? = nil) {
        self.category = category
        self.text = text
        self.from = from
        self.until = until
    }
}

public enum TrainerTrigger: Codable, Sendable, Equatable {
    case created
    case weekEnded(Int)
    case workout(activityId: Int64, day: Day)
    case request(TrainerRequest)
    case strengthChanged
}

public enum TrainerChangeKind: String, Codable, Sendable {
    case changed
    case added
    case removed
    case moved
    case unchanged
    case skeleton
    case newWeek
}

public struct TrainerChange: Codable, Sendable, Equatable {
    public var kind: TrainerChangeKind
    public var day: Day?
    public var weekIndex: Int?
    public var title: String
    public var before: String?
    public var after: String?
    public var reason: String

    public init(kind: TrainerChangeKind, day: Day? = nil, weekIndex: Int? = nil, title: String, before: String? = nil, after: String? = nil, reason: String) {
        self.kind = kind
        self.day = day
        self.weekIndex = weekIndex
        self.title = title
        self.before = before
        self.after = after
        self.reason = reason
    }
}

public struct TrainerVersion: Codable, Sendable, Equatable {
    public var number: Int
    public var createdAt: Date
    public var trigger: TrainerTrigger
    public var summary: String
    public var changes: [TrainerChange]

    public init(number: Int, createdAt: Date, trigger: TrainerTrigger, summary: String, changes: [TrainerChange]) {
        self.number = number
        self.createdAt = createdAt
        self.trigger = trigger
        self.summary = summary
        self.changes = changes
    }
}

public struct TrainerPlan: Codable, Sendable, Equatable {
    public var target: TrainerTarget
    public var structure: [Int: TrainerDayKind]
    public var paces: TrainerPaces
    public var weeks: [TrainerWeek]
    public var workouts: [TrainerWorkout]
    public var versions: [TrainerVersion]
    public var processedActivityIds: [Int64]
    public var strength: [TrainerStrengthSession]

    public init(target: TrainerTarget, structure: [Int: TrainerDayKind], paces: TrainerPaces, weeks: [TrainerWeek], workouts: [TrainerWorkout], versions: [TrainerVersion], processedActivityIds: [Int64] = [], strength: [TrainerStrengthSession] = []) {
        self.target = target
        self.structure = structure
        self.paces = paces
        self.weeks = weeks
        self.workouts = workouts
        self.versions = versions
        self.processedActivityIds = processedActivityIds
        self.strength = strength
    }

    private enum CodingKeys: String, CodingKey {
        case target, structure, paces, weeks, workouts, versions, processedActivityIds, strength
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            target: try container.decode(TrainerTarget.self, forKey: .target),
            structure: try container.decode([Int: TrainerDayKind].self, forKey: .structure),
            paces: try container.decode(TrainerPaces.self, forKey: .paces),
            weeks: try container.decode([TrainerWeek].self, forKey: .weeks),
            workouts: try container.decode([TrainerWorkout].self, forKey: .workouts),
            versions: try container.decode([TrainerVersion].self, forKey: .versions),
            processedActivityIds: try container.decodeIfPresent([Int64].self, forKey: .processedActivityIds) ?? [],
            strength: try container.decodeIfPresent([TrainerStrengthSession].self, forKey: .strength) ?? []
        )
    }
}

public struct TrainerRun: Sendable, Equatable {
    public var activityId: Int64
    public var day: Day
    public var meters: Double
    public var seconds: Double
    public var kind: RunKind
    public var averageHeartRate: Double?
    public var fadeKm: Int?
    public var pauses: Int?
    public var activeOnTarget: Int?
    public var activeTotal: Int?

    public init(activityId: Int64, day: Day, meters: Double, seconds: Double, kind: RunKind, averageHeartRate: Double? = nil, fadeKm: Int? = nil, pauses: Int? = nil, activeOnTarget: Int? = nil, activeTotal: Int? = nil) {
        self.activityId = activityId
        self.day = day
        self.meters = meters
        self.seconds = seconds
        self.kind = kind
        self.averageHeartRate = averageHeartRate
        self.fadeKm = fadeKm
        self.pauses = pauses
        self.activeOnTarget = activeOnTarget
        self.activeTotal = activeTotal
    }
}

public struct TrainerHistory: Sendable, Equatable {
    public var runs: [TrainerRun]
    public var readiness: [Day: Int]
    public var predictions: [Double: Double]
    public var strength: [TrainerStrengthDone]

    public init(runs: [TrainerRun], readiness: [Day: Int] = [:], predictions: [Double: Double] = [:], strength: [TrainerStrengthDone] = []) {
        self.runs = runs
        self.readiness = readiness
        self.predictions = predictions
        self.strength = strength
    }
}

public enum TrainerDayStatus: String, Sendable, Equatable {
    case planned
    case done
    case partial
    case offTarget
    case missed
    case skipped
    case today
}
