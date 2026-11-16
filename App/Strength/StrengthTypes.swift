import Foundation
import GarminAPI
import Insights
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
}

struct StrengthDay: Identifiable, Equatable {
    var id: String { day.iso }
    let day: Day
    let run: String?
    let runKind: TrainerDayKind?
    let strength: String?
}

struct StrengthVolumeRow: Identifiable, Equatable {
    var id: MuscleGroup { group }
    let group: MuscleGroup
    let weekly: [Double]
}

struct StrengthExerciseResult: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let planned: Int
    let done: Int
    let reps: [Int?]
}
