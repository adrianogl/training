import Foundation
import GarminAPI
import Insights
import MFIT
import TrainingCore

struct BodyMapPart: Sendable {
    let slug: String
    let paths: [String]
}

struct StrengthSession: Identifiable, Equatable, Sendable {
    let id: Int64
    let day: Day
    let title: String
    let minutes: Int?
    let averageHR: Int?
    let maxHR: Int?
    var workoutId: Int64?
    var effort: Int?
}

struct StrengthProgramCache: Codable, Sendable {
    let program: MFITProgram?
    let known: [MFITWorkout]
    var loads: [MFITLoadRecord] = []
    var watchProcessed: [Int64] = []

    init(program: MFITProgram?, known: [MFITWorkout], loads: [MFITLoadRecord] = [], watchProcessed: [Int64] = []) {
        self.program = program
        self.known = known
        self.loads = loads
        self.watchProcessed = watchProcessed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        program = try container.decodeIfPresent(MFITProgram.self, forKey: .program)
        known = try container.decodeIfPresent([MFITWorkout].self, forKey: .known) ?? []
        loads = try container.decodeIfPresent([MFITLoadRecord].self, forKey: .loads) ?? []
        watchProcessed = try container.decodeIfPresent([Int64].self, forKey: .watchProcessed) ?? []
    }
}

struct StrengthLoadPoint: Identifiable, Equatable {
    var id: String { day.iso }
    let day: Day
    let top: Double
    let loads: [Double]
    let workout: String
    var fromWatch = false
}

struct StrengthLoadSeries: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let name: String
    let workouts: [String]
    let points: [StrengthLoadPoint]

    var current: Double { points.last?.top ?? 0 }
    var change: Double? { points.count > 1 ? current - (points.first?.top ?? current) : nil }
    var record: StrengthLoadPoint? { points.max { $0.top == $1.top ? $0.day > $1.day : $0.top < $1.top } }

    var previousBest: Double? { points.dropLast().map(\.top).max() }

    var isNewRecord: Bool {
        guard let previousBest, let last = points.last else { return false }
        return last.top > previousBest
    }
}

struct StrengthDay: Identifiable, Equatable {
    var id: String { day.iso }
    let day: Day
    let run: String?
    let runKind: TrainerDayKind?
    let strength: String?
}

struct StrengthGroupTotal: Identifiable, Equatable {
    var id: MuscleGroup { group }
    let group: MuscleGroup
    let sets: Double
    let level: Int
}

struct StrengthVolumeRow: Identifiable, Equatable {
    var id: MuscleGroup { group }
    let group: MuscleGroup
    let weekly: [Double]
}

struct WeeklyStrengthRecord: Equatable {
    let name: String
    let top: Double
    let gain: Double
}

struct WeeklyStrengthSummary: Equatable {
    let done: Int
    let planned: Int
    let sets: Int
    let groups: [StrengthGroupTotal]
    let records: [WeeklyStrengthRecord]
    let missed: [String]
    let titles: [Day: String]
}

struct StrengthLegDay: Equatable {
    let title: String
    let sets: Int
    let legSets: Int
}
