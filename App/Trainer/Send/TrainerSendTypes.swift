import CryptoKit
import Foundation
import TrainingCore

enum TrainerSendKind: String, Codable, CaseIterable {
    case run, strength
}

enum TrainerSendFilter: String, Codable, CaseIterable, Identifiable {
    case run, strength, both

    var id: String { rawValue }

    var kinds: Set<TrainerSendKind> {
        switch self {
        case .run: [.run]
        case .strength: [.strength]
        case .both: [.run, .strength]
        }
    }
}

enum TrainerSendStatus: Equatable {
    case new, changed, current
}

struct TrainerSentRecord: Codable, Equatable {
    let workoutId: Int64
    let signature: String
    let day: String
    let kind: TrainerSendKind
}

struct TrainerSendSettings: Codable, Equatable {
    var runFromTrainer = false
    var auto: TrainerSendFilter?
}

struct TrainerSendItem: Identifiable, Equatable {
    let key: String
    let day: Day
    let kind: TrainerSendKind
    let title: String
    let payload: Data

    var id: String { key }

    var signature: String {
        SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    }
}
