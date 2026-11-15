import Foundation
import Insights
import TrainingCore

struct TrainerChatSwap: Identifiable, Hashable {
    let first: Day
    let second: Day

    var id: String { first.iso + second.iso }
}

struct TrainerRequestPrefill: Identifiable, Hashable {
    let category: TrainerRequestCategory
    let text: String

    var id: String { category.rawValue + text }
}

enum TrainerChatAction: Hashable {
    case swap(TrainerChatSwap)
    case request(TrainerRequestPrefill)
}
