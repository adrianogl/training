import Foundation
import GarminAPI
import Insights
import MFIT
import TrainingCore

struct BodyMapPart: Sendable {
    let slug: String
    let paths: [String]
}

enum StrengthRoute: Hashable, Codable {
    case workout(Int64)
    case session(Int64)
    case volume
    case history
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
}

struct StrengthDay: Identifiable, Equatable {
    var id: String { day.iso }
    let day: Day
    let run: String?
    let runKind: TrainerDayKind?
    var runKilometers: String? = nil
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
