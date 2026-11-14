import Foundation
import SwiftData

@Model
public final class GoalRecord {
    public var id: UUID = UUID()
    public var kind: String = GoalKind.time.rawValue
    public var distanceKm: Double = 0
    public var targetSeconds: Double? = nil
    public var deadline: String? = nil
    public var paceSecondsPerKm: Double? = nil
    public var archived: Bool = false
    public var achievedAt: String? = nil
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now
    public var deletedAt: Date? = nil

    public var goalKind: GoalKind? {
        get { GoalKind(rawValue: kind) }
        set { kind = newValue?.rawValue ?? kind }
    }

    public init(
        id: UUID = UUID(),
        kind: GoalKind,
        distanceKm: Double,
        targetSeconds: Double? = nil,
        deadline: String? = nil,
        paceSecondsPerKm: Double? = nil,
        archived: Bool = false,
        achievedAt: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind.rawValue
        self.distanceKm = distanceKm
        self.targetSeconds = targetSeconds
        self.deadline = deadline
        self.paceSecondsPerKm = paceSecondsPerKm
        self.archived = archived
        self.achievedAt = achievedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
