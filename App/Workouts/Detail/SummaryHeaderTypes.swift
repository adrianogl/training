import Foundation

struct SummaryStatItem: Identifiable {
    let value: String
    let caption: String

    var id: String { caption }
}
