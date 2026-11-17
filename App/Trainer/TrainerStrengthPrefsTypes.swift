import Foundation
import Insights

struct TrainerStrengthPrefs: Codable, Equatable {
    var pain: Set<BodyRegion> = []
    var painMarkedAt: Date?
    var swaps: [String: [String: String]] = [:]
    var keptOriginal: Set<String> = []
}
