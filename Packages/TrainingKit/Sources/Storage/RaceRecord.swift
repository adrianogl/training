import Foundation
import SwiftData

@Model
public final class RaceRecord {
    public var id: UUID = UUID()
    public var name: String = ""
    public var day: String = ""
    public var startTime: String? = nil
    public var distance: Double = 0
    public var goalSeconds: Double? = nil
    public var priority: String = "C"
    public var city: String? = nil
    public var gpxData: Data? = nil
    public var manualPacesData: Data? = nil
    public var customLabelsData: Data? = nil
    public var resultActivityId: Int64? = nil
    public var frozenTargetSeconds: Double? = nil
    public var frozenTargetDay: String? = nil
    public var manuallyUnlinked: Bool = false
    public var updatedAt: Date = Date.now

    public init(
        id: UUID = UUID(),
        name: String,
        day: String,
        distance: Double,
        startTime: String? = nil,
        goalSeconds: Double? = nil,
        priority: RacePriority = .c,
        city: String? = nil,
        gpxData: Data? = nil,
        manualPacesData: Data? = nil,
        customLabelsData: Data? = nil,
        resultActivityId: Int64? = nil,
        frozenTargetSeconds: Double? = nil,
        frozenTargetDay: String? = nil,
        manuallyUnlinked: Bool = false,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.day = day
        self.distance = distance
        self.startTime = startTime
        self.goalSeconds = goalSeconds
        self.priority = priority.rawValue
        self.city = city
        self.gpxData = gpxData
        self.manualPacesData = manualPacesData
        self.customLabelsData = customLabelsData
        self.resultActivityId = resultActivityId
        self.frozenTargetSeconds = frozenTargetSeconds
        self.frozenTargetDay = frozenTargetDay
        self.manuallyUnlinked = manuallyUnlinked
        self.updatedAt = updatedAt
    }
}
