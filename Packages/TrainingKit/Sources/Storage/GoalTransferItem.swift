import Foundation

public struct GoalTransferItem: Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: GoalKind
    public var distanceKm: Double
    public var targetSeconds: Double?
    public var deadline: String?
    public var paceSecondsPerKm: Double?
    public var archived: Bool
    public var achievedAt: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(_ record: GoalRecord) {
        id = record.id
        kind = record.goalKind ?? .time
        distanceKm = record.distanceKm
        targetSeconds = record.targetSeconds
        deadline = record.deadline
        paceSecondsPerKm = record.paceSecondsPerKm
        archived = record.archived
        achievedAt = record.achievedAt
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    public func makeRecord() -> GoalRecord {
        GoalRecord(
            id: id, kind: kind, distanceKm: distanceKm, targetSeconds: targetSeconds, deadline: deadline,
            paceSecondsPerKm: paceSecondsPerKm, archived: archived, achievedAt: achievedAt, createdAt: createdAt, updatedAt: updatedAt
        )
    }

    public func apply(to record: GoalRecord) {
        record.goalKind = kind
        record.distanceKm = distanceKm
        record.targetSeconds = targetSeconds
        record.deadline = deadline
        record.paceSecondsPerKm = paceSecondsPerKm
        record.archived = archived
        record.achievedAt = achievedAt
        record.createdAt = createdAt
        record.updatedAt = updatedAt
        record.deletedAt = nil
    }
}
