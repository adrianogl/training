import Foundation

public struct PaceProSplit: Sendable, Equatable, Codable {
    public var distance: Double
    public var time: Double

    public init(distance: Double, time: Double) {
        self.distance = distance
        self.time = time
    }
}

public struct PaceProSummary: Sendable, Equatable, Codable, Identifiable {
    public var id: Int64
    public var name: String
    public var distance: Double
    public var goalSeconds: Double?
    public var created: String?

    public init(id: Int64, name: String, distance: Double, goalSeconds: Double?, created: String?) {
        self.id = id
        self.name = name
        self.distance = distance
        self.goalSeconds = goalSeconds
        self.created = created
    }
}

public struct PaceProPlan: Sendable, Equatable, Codable, Identifiable {
    public var summary: PaceProSummary
    public var splits: [PaceProSplit]

    public init(summary: PaceProSummary, splits: [PaceProSplit]) {
        self.summary = summary
        self.splits = splits
    }

    public var id: Int64 { summary.id }

    public var kilometerSeconds: [Double] {
        var previous = PaceProSplit(distance: 0, time: 0)
        return splits.compactMap { split in
            defer { previous = split }
            let distance = split.distance - previous.distance
            guard distance >= 500 else { return nil }
            return (split.time - previous.time) * 1_000 / distance
        }
    }
}

struct PaceBandSummaryDTO: Decodable {
    let paceBandPk: Int64
    let name: String?
    let totalDistance: Double?
    let goalTime: Double?
    let createdDate: String?
}

struct PaceBandSplitDTO: Decodable {
    let cumulativeDistanceFromStart: Double?
    let cumulativeTimeFromStart: Double?
}

struct PaceBandDTO: Decodable {
    let paceBandSummary: PaceBandSummaryDTO?
    let paceBandSplits: [PaceBandSplitDTO]?
}
