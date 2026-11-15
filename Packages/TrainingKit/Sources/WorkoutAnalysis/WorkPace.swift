import FITReader
import Foundation
import Storage

private typealias C = WorkPaceConstants

public struct WorkPace: Sendable, Equatable {
    public var seconds: Double
    public var meters: Double

    public init(seconds: Double, meters: Double) {
        self.seconds = seconds
        self.meters = meters
    }

    public var pace: Double { seconds / meters * C.metersPerKilometer }
}

public func workPace(_ record: ActivityRecord) -> WorkPace? {
    guard let data = record.structureData,
          let structure = try? JSONDecoder().decode(WorkoutStructure.self, from: data),
          hasPrescription(structure)
    else { return nil }
    return workPace(blocks: buildBlocks(structure, zones: nil))
}

public func workPace(blocks: [WorkoutBlock]) -> WorkPace? {
    let laps = blocks.filter { $0.kind == .active }.flatMap(\.laps).filter { lap in
        lap.distance >= C.minimumLapMeters && lap.timerSeconds > 0
            && lap.timerSeconds / lap.distance * C.metersPerKilometer <= C.maximumLapPace
            && (lap.intensity == nil || lap.intensity == .active)
    }
    let meters = laps.reduce(0.0) { $0 + $1.distance }
    guard meters > 0 else { return nil }
    return WorkPace(seconds: laps.reduce(0.0) { $0 + $1.timerSeconds }, meters: meters)
}
