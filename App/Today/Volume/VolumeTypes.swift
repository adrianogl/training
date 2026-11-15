import TrainingCore

struct VolumePoint: Equatable, Identifiable {
    let start: Day
    let kilometers: Double
    let plannedKm: Double?
    let isCurrent: Bool

    var id: Day { start }

    var ratio: Double? {
        guard let plannedKm, plannedKm > 0 else { return nil }
        return kilometers / plannedKm
    }

    var percent: Int? { ratio.map { Int(($0 * 100).rounded()) } }
}

struct VolumeSeries: Equatable {
    let points: [VolumePoint]
    let average4Weeks: Double
    let adherence: Double?
    let projectedKm: Double?

    var current: VolumePoint? { points.last }
    var adherencePercent: Int? { adherence.map { Int(($0 * 100).rounded()) } }
}
