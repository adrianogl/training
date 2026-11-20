import Foundation
import Insights

enum ExerciseMediaSource: String, Codable, Sendable {
    case freeExerciseDb, wger, drawing
}

struct ExerciseMedia: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let source: ExerciseMediaSource
    let frames: [String]
    let equivalent: Bool
    let steps: [String]
    let author: String?
    let license: String?
    let link: String?
    let pattern: MovementPattern?
}

enum ExerciseKey: Hashable, Codable, Sendable {
    case catalog(String)
    case mfit(String)
}

struct ExerciseMediaFile: Decodable, Sendable {
    let mediaByCatalogId: [String: [ExerciseMediaEntry]]
    let catalogIdByMFITName: [String: String]
    let stepsByPattern: [String: ExercisePatternSteps]

    enum CodingKeys: String, CodingKey {
        case mediaByCatalogId = "midias"
        case catalogIdByMFITName = "mfit"
        case stepsByPattern = "padroes"
    }
}

struct ExerciseMediaEntry: Decodable, Sendable {
    let source: ExerciseMediaSource
    let frames: [String]
    let equivalent: Bool
    let steps: [String]?
    let author: String?
    let license: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case source = "origem"
        case frames = "quadros"
        case equivalent = "equivalente"
        case steps = "passos"
        case author = "autor"
        case license = "licenca"
        case link
    }
}

struct ExercisePatternSteps: Decodable, Sendable {
    let steps: [String]

    enum CodingKeys: String, CodingKey {
        case steps = "passos"
    }
}
