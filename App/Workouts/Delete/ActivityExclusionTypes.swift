import Foundation

struct ActivityExclusions: Codable, Equatable, Sendable {
    var deleted: [Int64] = []
    var own: [Int64] = []

    func merged(with other: ActivityExclusions) -> ActivityExclusions {
        ActivityExclusions(deleted: Array(Set(deleted + other.deleted)).sorted(), own: Array(Set(own + other.own)).sorted())
    }
}
