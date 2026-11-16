import Foundation
import GarminAPI
import Insights
import TrainingCore
import WorkoutAnalysis

enum SessionKind: String, Equatable, Sendable, Codable {
    case easy, threshold, intervals, long, race

    var isHard: Bool { self != .easy }
    var isQuality: Bool { self == .threshold || self == .intervals }

    init(run: RunKind) {
        switch run {
        case .intervals: self = .intervals
        case .tempo: self = .threshold
        case .race: self = .race
        case .long: self = .long
        case .easy: self = .easy
        }
    }

    init?(trainer: TrainerDayKind) {
        switch trainer {
        case .easy, .optionalEasy: self = .easy
        case .threshold: self = .threshold
        case .vo2max: self = .intervals
        case .long: self = .long
        case .race: self = .race
        case .off: return nil
        }
    }

    init(title: String, steps: [PlannedStep]) {
        typealias C = PlannedSessionConstants
        let text = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        func mentions(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        if mentions(C.raceWords) {
            self = .race
        } else if mentions(C.longWords) {
            self = .long
        } else if mentions(C.intervalWords) {
            self = .intervals
        } else if mentions(C.thresholdWords) {
            self = .threshold
        } else if steps.flatMap(\.flattened).filter({ $0.kind == .active }).count >= C.intervalActiveSteps {
            self = .intervals
        } else {
            self = .easy
        }
    }
}

struct PlannedSession: Equatable, Sendable {
    let day: Day
    let title: String
    let kilometers: Double
    let kind: SessionKind
}

enum PlannedSessions {
    private typealias C = PlannedSessionConstants

    static func merge(garmin: [PlannedWorkout], trainer: [TrainerWorkout]) -> [PlannedSession] {
        let fromGarmin = garmin.compactMap { workout -> PlannedSession? in
            guard let day = Day(iso: workout.day) else { return nil }
            return PlannedSession(
                day: day,
                title: workout.title,
                kilometers: (workout.estimatedMeters ?? 0) / C.metersPerKilometer,
                kind: SessionKind(title: workout.title, steps: workout.steps)
            )
        }
        let covered = Set(fromGarmin.map(\.day))
        let fromTrainer = trainer.compactMap { workout -> PlannedSession? in
            guard !covered.contains(workout.day), let kind = SessionKind(trainer: workout.kind) else { return nil }
            return PlannedSession(day: workout.day, title: TrainerText.dayName(workout), kilometers: workout.totalMeters / C.metersPerKilometer, kind: kind)
        }
        return (fromGarmin + fromTrainer).sorted { $0.day < $1.day }
    }
}
