import Foundation
import TrainingCore
import WorkoutAnalysis

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
    case general
    case base
    case build
    case specific
    case taper

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = TrainerPhase(rawValue: value) ?? .base
    }
}

public enum TrainerStepKind: String, Codable, Sendable {
    case warmup
    case work
    case recovery
    case cooldown
    case steady
}

public enum TrainerMethod: String, Codable, Sendable, CaseIterable {
    case cruiseIntervals
    case tempo
    case intervals
    case repetition
    case racePace
    case goalPace

    public var title: String { TrainerEngineText.methodTitle(self) }
    public var source: String { TrainerEngineText.methodSource(self) }
    public var label: String { TrainerEngineText.methodLabel(self) }
}

public enum TrainerVariant: String, Codable, Sendable, CaseIterable {
    case strides
    case mediumLong
    case fartlek
    case hills
    case continuousTempo
    case progressiveThreshold
    case progressiveLong
    case fastFinish
    case racePaceLong
}

public enum TrainerLongMode: String, Codable, Sendable, CaseIterable {
    case continuous
    case blocks
}

public struct TrainerLongSuggestion: Sendable, Equatable {
    public var flagged: Int
    public var total: Int

    public init(flagged: Int, total: Int) {
        self.flagged = flagged
        self.total = total
    }
}

public struct TrainerStep: Codable, Sendable, Equatable {
    public var kind: TrainerStepKind
    public var repeats: Int
    public var meters: Double
    public var restSeconds: Double?
    public var paceLow: Double?
    public var paceHigh: Double?
    public var method: TrainerMethod?

    public init(kind: TrainerStepKind, repeats: Int = 1, meters: Double, restSeconds: Double? = nil, paceLow: Double? = nil, paceHigh: Double? = nil, method: TrainerMethod? = nil) {
        self.kind = kind
        self.repeats = repeats
        self.meters = meters
        self.restSeconds = restSeconds
        self.paceLow = paceLow
        self.paceHigh = paceHigh
        self.method = method
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
    public var method: TrainerMethod?
    public var edited: Bool
    public var variant: TrainerVariant?

    public var id: String { day.iso }

    public init(day: Day, kind: TrainerDayKind, title: String, totalMeters: Double, steps: [TrainerStep], paceLow: Double? = nil, paceHigh: Double? = nil, note: String? = nil, rationale: String, method: TrainerMethod? = nil, edited: Bool = false, variant: TrainerVariant? = nil) {
        self.day = day
        self.kind = kind
        self.title = title
        self.totalMeters = totalMeters
        self.steps = steps
        self.paceLow = paceLow
        self.paceHigh = paceHigh
        self.note = note
        self.rationale = rationale
        self.method = method
        self.edited = edited
        self.variant = variant
    }

    private enum CodingKeys: String, CodingKey {
        case day, kind, title, totalMeters, steps, paceLow, paceHigh, note, rationale, method, edited, variant
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            day: try container.decode(Day.self, forKey: .day),
            kind: try container.decode(TrainerDayKind.self, forKey: .kind),
            title: try container.decode(String.self, forKey: .title),
            totalMeters: try container.decode(Double.self, forKey: .totalMeters),
            steps: try container.decode([TrainerStep].self, forKey: .steps),
            paceLow: try container.decodeIfPresent(Double.self, forKey: .paceLow),
            paceHigh: try container.decodeIfPresent(Double.self, forKey: .paceHigh),
            note: try container.decodeIfPresent(String.self, forKey: .note),
            rationale: try container.decode(String.self, forKey: .rationale),
            method: try container.decodeIfPresent(TrainerMethod.self, forKey: .method),
            edited: try container.decodeIfPresent(Bool.self, forKey: .edited) ?? false,
            variant: (try? container.decodeIfPresent(String.self, forKey: .variant)).flatMap(TrainerVariant.init(rawValue:))
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(totalMeters, forKey: .totalMeters)
        try container.encode(steps, forKey: .steps)
        try container.encodeIfPresent(paceLow, forKey: .paceLow)
        try container.encodeIfPresent(paceHigh, forKey: .paceHigh)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(rationale, forKey: .rationale)
        try container.encodeIfPresent(method, forKey: .method)
        if edited { try container.encode(edited, forKey: .edited) }
        try container.encodeIfPresent(variant, forKey: .variant)
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
    public var baseLongMeters: Double?
    public var calm: Bool
    public var lightKind: TrainerLightKind?
    public var baseMeters: Double?

    public var id: Int { index }

    public init(index: Int, start: Day, phase: TrainerPhase, isRecovery: Bool, plannedMeters: Double, targetMeters: Double? = nil, longMeters: Double, thresholdFocus: String, vo2Focus: String, baseLongMeters: Double? = nil, calm: Bool = false, lightKind: TrainerLightKind? = nil, baseMeters: Double? = nil) {
        self.index = index
        self.start = start
        self.phase = phase
        self.isRecovery = isRecovery
        self.plannedMeters = plannedMeters
        self.targetMeters = targetMeters ?? plannedMeters
        self.longMeters = longMeters
        self.thresholdFocus = thresholdFocus
        self.vo2Focus = vo2Focus
        self.baseLongMeters = baseLongMeters
        self.calm = calm
        self.lightKind = lightKind
        self.baseMeters = baseMeters
    }

    private enum CodingKeys: String, CodingKey {
        case index, start, phase, isRecovery, plannedMeters, targetMeters, longMeters, thresholdFocus, vo2Focus, baseLongMeters, calm, lightKind, baseMeters
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
            vo2Focus: try container.decode(String.self, forKey: .vo2Focus),
            baseLongMeters: try container.decodeIfPresent(Double.self, forKey: .baseLongMeters),
            calm: try container.decodeIfPresent(Bool.self, forKey: .calm) ?? false,
            lightKind: try container.decodeIfPresent(TrainerLightKind.self, forKey: .lightKind),
            baseMeters: try container.decodeIfPresent(Double.self, forKey: .baseMeters)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(start, forKey: .start)
        try container.encode(phase, forKey: .phase)
        try container.encode(isRecovery, forKey: .isRecovery)
        try container.encode(plannedMeters, forKey: .plannedMeters)
        try container.encode(targetMeters, forKey: .targetMeters)
        try container.encode(longMeters, forKey: .longMeters)
        try container.encode(thresholdFocus, forKey: .thresholdFocus)
        try container.encode(vo2Focus, forKey: .vo2Focus)
        try container.encodeIfPresent(baseLongMeters, forKey: .baseLongMeters)
        if calm { try container.encode(calm, forKey: .calm) }
        try container.encodeIfPresent(lightKind, forKey: .lightKind)
        try container.encodeIfPresent(baseMeters, forKey: .baseMeters)
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
    public static let defaultMinutes = 45

    public var id: UUID
    public var weekday: Int
    public var group: TrainerStrengthGroup
    public var legLoad: TrainerStrengthLoad
    public var name: String
    public var source: TrainerStrengthSource
    public var intensity: TrainerStrengthIntensity
    public var minutes: Int
    public var place: StrengthPlace

    public init(
        id: UUID = UUID(), weekday: Int, group: TrainerStrengthGroup, legLoad: TrainerStrengthLoad, name: String,
        source: TrainerStrengthSource = .trainer, intensity: TrainerStrengthIntensity = .moderate,
        minutes: Int = TrainerStrengthSession.defaultMinutes, place: StrengthPlace = .gym
    ) {
        self.id = id
        self.weekday = weekday
        self.group = group
        self.legLoad = legLoad
        self.name = name
        self.source = source
        self.intensity = intensity
        self.minutes = minutes
        self.place = place
    }

    enum CodingKeys: String, CodingKey {
        case id, weekday, group, legLoad, name, source, intensity, minutes, place
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        weekday = try container.decode(Int.self, forKey: .weekday)
        group = try container.decode(TrainerStrengthGroup.self, forKey: .group)
        legLoad = try container.decode(TrainerStrengthLoad.self, forKey: .legLoad)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decodeIfPresent(TrainerStrengthSource.self, forKey: .source)
            ?? (id.uuidString.hasPrefix(StrengthSessionConstants.mfitIdPrefix) ? .mfit : .trainer)
        intensity = try container.decodeIfPresent(TrainerStrengthIntensity.self, forKey: .intensity) ?? .moderate
        minutes = try container.decodeIfPresent(Int.self, forKey: .minutes) ?? Self.defaultMinutes
        place = try container.decodeIfPresent(StrengthPlace.self, forKey: .place) ?? .gym
    }
}

public struct TrainerDayPreference: Codable, Sendable, Equatable, Hashable {
    public var runs: Int
    public var optional: Bool
    public var offDays: Set<Int>
    public var longDay: Int

    public static let standard = TrainerDayPreference(runs: 6, optional: true, offDays: [7], longDay: 6)
    public static let runsRange = 3...7

    public init(runs: Int, optional: Bool, offDays: Set<Int>, longDay: Int) {
        self.runs = runs
        self.optional = optional
        self.offDays = offDays
        self.longDay = longDay
    }

    public init(structure: [Int: TrainerDayKind]) {
        let kinds = (1...7).map { structure[$0] ?? .off }
        let runs = kinds.filter { $0 != .off }.count
        self.init(
            runs: min(max(runs, Self.runsRange.lowerBound), Self.runsRange.upperBound),
            optional: kinds.contains(.optionalEasy),
            offDays: Set((1...7).filter { (structure[$0] ?? .off) == .off }),
            longDay: (1...7).first { structure[$0] == .long } ?? Self.standard.longDay
        )
    }

    private enum CodingKeys: String, CodingKey {
        case runs, optional, offDays, longDay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let standard = Self.standard
        self.init(
            runs: try container.decodeIfPresent(Int.self, forKey: .runs) ?? standard.runs,
            optional: try container.decodeIfPresent(Bool.self, forKey: .optional) ?? standard.optional,
            offDays: try container.decodeIfPresent(Set<Int>.self, forKey: .offDays) ?? standard.offDays,
            longDay: try container.decodeIfPresent(Int.self, forKey: .longDay) ?? standard.longDay
        )
    }
}

public struct TrainerDayWarning: Sendable, Equatable, Hashable {
    public var days: [Int]
    public var text: String
    public var isSoft: Bool

    public init(days: [Int], text: String, isSoft: Bool = false) {
        self.days = days
        self.text = text
        self.isSoft = isSoft
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
    case paceDistance
}

public struct TrainerTarget: Codable, Sendable, Equatable {
    public var kind: TrainerTargetKind
    public var name: String
    public var raceId: UUID?
    public var date: Day?
    public var distanceMeters: Double?
    public var goalSeconds: Double?
    public var text: String?
    public var goalPace: Double?

    public init(kind: TrainerTargetKind, name: String, raceId: UUID? = nil, date: Day? = nil, distanceMeters: Double? = nil, goalSeconds: Double? = nil, text: String? = nil, goalPace: Double? = nil) {
        self.kind = kind
        self.name = name
        self.raceId = raceId
        self.date = date
        self.distanceMeters = distanceMeters
        self.goalSeconds = goalSeconds
        self.text = text
        self.goalPace = goalPace
    }
}

public enum TrainerPaceSource: String, Codable, Sendable, Equatable {
    case work
    case prediction
    case history
    case fallback
    case manual
}

public enum TrainerPaceKind: String, Codable, Sendable, CaseIterable {
    case easy
    case long
    case threshold
    case vo2max
    case race
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
    public var thresholdSource: TrainerPaceSource?
    public var vo2Source: TrainerPaceSource?
    public var thresholdWorkRuns: Int?
    public var vo2WorkRuns: Int?

    public init(easy: Double, long: Double, threshold: Double, vo2max: Double, race: Double? = nil, easyRuns: Int = 0, thresholdRuns: Int = 0, vo2Runs: Int = 0, thresholdSource: TrainerPaceSource? = nil, vo2Source: TrainerPaceSource? = nil, thresholdWorkRuns: Int? = nil, vo2WorkRuns: Int? = nil) {
        self.easy = easy
        self.long = long
        self.threshold = threshold
        self.vo2max = vo2max
        self.race = race
        self.easyRuns = easyRuns
        self.thresholdRuns = thresholdRuns
        self.vo2Runs = vo2Runs
        self.thresholdSource = thresholdSource
        self.vo2Source = vo2Source
        self.thresholdWorkRuns = thresholdWorkRuns
        self.vo2WorkRuns = vo2WorkRuns
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
    case lightWeek(Day)
    case longModeChanged
    case edited(TrainerEdit)
    case readiness(day: Day, score: Int)
}

public struct TrainerEdit: Codable, Sendable, Equatable {
    public var target: TrainerTarget?
    public var startMeters: Double?
    public var peakMeters: Double?
    public var structure: [Int: TrainerDayKind]?
    public var strength: [TrainerStrengthSession]?
    public var longMode: TrainerLongMode?
    public var paceOverrides: [TrainerPaceKind: Double]?
    public var days: [Day]
    public var dayPreference: TrainerDayPreference?

    public init(
        target: TrainerTarget? = nil, startMeters: Double? = nil, peakMeters: Double? = nil, structure: [Int: TrainerDayKind]? = nil,
        strength: [TrainerStrengthSession]? = nil, longMode: TrainerLongMode? = nil, paceOverrides: [TrainerPaceKind: Double]? = nil,
        days: [Day] = [], dayPreference: TrainerDayPreference? = nil
    ) {
        self.target = target
        self.startMeters = startMeters
        self.peakMeters = peakMeters
        self.structure = structure
        self.strength = strength
        self.longMode = longMode
        self.paceOverrides = paceOverrides
        self.days = days
        self.dayPreference = dayPreference
    }
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
    public var startMeters: Double?
    public var peakMeters: Double?
    public var lightWeeks: [Day]
    public var earlyLightWeeks: [Day: TrainerLightKind]
    public var calmWeeks: [Day]
    public var longMode: TrainerLongMode
    public var longStage: Int
    public var longStageStreak: Int
    public var longStageMisses: Int
    public var paceOverrides: [TrainerPaceKind: Double]
    public var dayPreference: TrainerDayPreference
    public var endedOn: Day?

    public init(target: TrainerTarget, structure: [Int: TrainerDayKind], paces: TrainerPaces, weeks: [TrainerWeek], workouts: [TrainerWorkout], versions: [TrainerVersion], processedActivityIds: [Int64] = [], strength: [TrainerStrengthSession] = [], startMeters: Double? = nil, peakMeters: Double? = nil, lightWeeks: [Day] = [], earlyLightWeeks: [Day: TrainerLightKind] = [:], calmWeeks: [Day] = [], longMode: TrainerLongMode = .continuous, longStage: Int = 1, longStageStreak: Int = 0, longStageMisses: Int = 0, paceOverrides: [TrainerPaceKind: Double] = [:], dayPreference: TrainerDayPreference? = nil, endedOn: Day? = nil) {
        self.target = target
        self.structure = structure
        self.paces = paces
        self.weeks = weeks
        self.workouts = workouts
        self.versions = versions
        self.processedActivityIds = processedActivityIds
        self.strength = strength
        self.startMeters = startMeters
        self.peakMeters = peakMeters
        self.lightWeeks = lightWeeks
        self.earlyLightWeeks = earlyLightWeeks
        self.calmWeeks = calmWeeks
        self.longMode = longMode
        self.longStage = longStage
        self.longStageStreak = longStageStreak
        self.longStageMisses = longStageMisses
        self.paceOverrides = paceOverrides
        self.dayPreference = dayPreference ?? TrainerDayPreference(structure: structure)
        self.endedOn = endedOn
    }

    private enum CodingKeys: String, CodingKey {
        case target, structure, paces, weeks, workouts, versions, processedActivityIds, strength, startMeters, peakMeters, weeklyMeters, lightWeeks
        case earlyLightWeeks, calmWeeks, longMode, longStage, longStageStreak, longStageMisses, paceOverrides, dayPreference, endedOn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyMeters = try container.decodeIfPresent(Double.self, forKey: .weeklyMeters)
        let start = try container.decodeIfPresent(Double.self, forKey: .startMeters) ?? legacyMeters
        let peak = try container.decodeIfPresent(Double.self, forKey: .peakMeters)
            ?? legacyMeters.map { TrainerEngineConstants.legacyPeak(from: $0) }
        let early = try container.decodeIfPresent([String: TrainerLightKind].self, forKey: .earlyLightWeeks) ?? [:]
        self.init(
            target: try container.decode(TrainerTarget.self, forKey: .target),
            structure: try container.decode([Int: TrainerDayKind].self, forKey: .structure),
            paces: try container.decode(TrainerPaces.self, forKey: .paces),
            weeks: try container.decode([TrainerWeek].self, forKey: .weeks),
            workouts: try container.decode([TrainerWorkout].self, forKey: .workouts),
            versions: try container.decode([TrainerVersion].self, forKey: .versions),
            processedActivityIds: try container.decodeIfPresent([Int64].self, forKey: .processedActivityIds) ?? [],
            strength: try container.decodeIfPresent([TrainerStrengthSession].self, forKey: .strength) ?? [],
            startMeters: start, peakMeters: peak,
            lightWeeks: try container.decodeIfPresent([Day].self, forKey: .lightWeeks) ?? [],
            earlyLightWeeks: Dictionary(early.compactMap { key, kind in Day(iso: key).map { ($0, kind) } }, uniquingKeysWith: { first, _ in first }),
            calmWeeks: try container.decodeIfPresent([Day].self, forKey: .calmWeeks) ?? [],
            longMode: try container.decodeIfPresent(TrainerLongMode.self, forKey: .longMode) ?? .continuous,
            longStage: try container.decodeIfPresent(Int.self, forKey: .longStage) ?? 1,
            longStageStreak: try container.decodeIfPresent(Int.self, forKey: .longStageStreak) ?? 0,
            longStageMisses: try container.decodeIfPresent(Int.self, forKey: .longStageMisses) ?? 0,
            paceOverrides: try container.decodeIfPresent([TrainerPaceKind: Double].self, forKey: .paceOverrides) ?? [:],
            dayPreference: try container.decodeIfPresent(TrainerDayPreference.self, forKey: .dayPreference),
            endedOn: try container.decodeIfPresent(Day.self, forKey: .endedOn)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(target, forKey: .target)
        try container.encode(structure, forKey: .structure)
        try container.encode(paces, forKey: .paces)
        try container.encode(weeks, forKey: .weeks)
        try container.encode(workouts, forKey: .workouts)
        try container.encode(versions, forKey: .versions)
        try container.encode(processedActivityIds, forKey: .processedActivityIds)
        try container.encode(strength, forKey: .strength)
        try container.encodeIfPresent(startMeters, forKey: .startMeters)
        try container.encodeIfPresent(peakMeters, forKey: .peakMeters)
        try container.encode(lightWeeks, forKey: .lightWeeks)
        if !earlyLightWeeks.isEmpty {
            try container.encode(Dictionary(uniqueKeysWithValues: earlyLightWeeks.map { ($0.key.iso, $0.value) }), forKey: .earlyLightWeeks)
        }
        if !calmWeeks.isEmpty { try container.encode(calmWeeks, forKey: .calmWeeks) }
        try container.encode(longMode, forKey: .longMode)
        try container.encode(longStage, forKey: .longStage)
        try container.encode(longStageStreak, forKey: .longStageStreak)
        try container.encode(longStageMisses, forKey: .longStageMisses)
        if !paceOverrides.isEmpty { try container.encode(paceOverrides, forKey: .paceOverrides) }
        try container.encode(dayPreference, forKey: .dayPreference)
        try container.encodeIfPresent(endedOn, forKey: .endedOn)
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
    public var firstPauseKm: Int?
    public var activeOnTarget: Int?
    public var activeTotal: Int?
    public var workPaceSeconds: Double?

    public init(activityId: Int64, day: Day, meters: Double, seconds: Double, kind: RunKind, averageHeartRate: Double? = nil, fadeKm: Int? = nil, pauses: Int? = nil, firstPauseKm: Int? = nil, activeOnTarget: Int? = nil, activeTotal: Int? = nil, workPaceSeconds: Double? = nil) {
        self.activityId = activityId
        self.day = day
        self.meters = meters
        self.seconds = seconds
        self.kind = kind
        self.averageHeartRate = averageHeartRate
        self.fadeKm = fadeKm
        self.pauses = pauses
        self.firstPauseKm = firstPauseKm
        self.activeOnTarget = activeOnTarget
        self.activeTotal = activeTotal
        self.workPaceSeconds = workPaceSeconds
    }
}

public struct TrainerHistory: Sendable, Equatable {
    public var runs: [TrainerRun]
    public var readiness: [Day: Int]
    public var predictions: [Double: Double]
    public var strength: [TrainerStrengthDone]
    public var predictionSeries: [Day: [Double: Double]]
    public var hrv: [Day: Double]
    public var restingHeartRate: [Day: Int]
    public var sleepSeconds: [Day: Int]
    public var dailyLoad: [Day: Double]

    public init(
        runs: [TrainerRun], readiness: [Day: Int] = [:], predictions: [Double: Double] = [:], strength: [TrainerStrengthDone] = [],
        predictionSeries: [Day: [Double: Double]] = [:], hrv: [Day: Double] = [:], restingHeartRate: [Day: Int] = [:],
        sleepSeconds: [Day: Int] = [:], dailyLoad: [Day: Double] = [:]
    ) {
        self.runs = runs
        self.readiness = readiness
        self.predictions = predictions
        self.strength = strength
        self.predictionSeries = predictionSeries
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.sleepSeconds = sleepSeconds
        self.dailyLoad = dailyLoad
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

public struct TrainerWorkoutDraft: Sendable, Equatable {
    public var isQuality: Bool
    public var repeats: Int
    public var blockMeters: Double
    public var pace: Double
    public var restSeconds: Double
    public var totalMeters: Double

    public init(isQuality: Bool, repeats: Int, blockMeters: Double, pace: Double, restSeconds: Double, totalMeters: Double) {
        self.isQuality = isQuality
        self.repeats = repeats
        self.blockMeters = blockMeters
        self.pace = pace
        self.restSeconds = restSeconds
        self.totalMeters = totalMeters
    }
}
