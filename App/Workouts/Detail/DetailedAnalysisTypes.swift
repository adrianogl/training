import Foundation

enum CoachPartState: Equatable {
    case pending
    case generated(String)
    case fallback(String)

    var text: String? {
        switch self {
        case .pending: nil
        case .generated(let text), .fallback(let text): text
        }
    }
}

struct DetailedKPITile: Identifiable, Equatable {
    let id: Int
    let value: String
    let caption: String
    let average: String?
    let isWorse: Bool
}

enum SimilarBarRole: Equatable {
    case clean, complete, partial, today
}

struct SimilarBar: Identifiable, Equatable {
    let id: Int64
    let label: String
    let percent: Double
    let role: SimilarBarRole
}
