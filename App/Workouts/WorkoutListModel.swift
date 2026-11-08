import Foundation
import Storage
import TrainingCore

enum WorkoutListModel {
    static func rows(filter: WorkoutFilter, records: [ActivityRecord]) -> [WorkoutRowData] {
        records
            .filter { filter.matches($0.typeKey) }
            .sorted { $0.start > $1.start }
            .map(row)
    }

    static func row(_ record: ActivityRecord) -> WorkoutRowData {
        let distance = record.distance.flatMap { $0 > 0 ? $0 : nil }
        let duration = (record.movingDuration ?? record.duration).flatMap { $0 > 0 ? $0 : nil }
        let isRun = ActivityTypeKey.isRun(record.typeKey)
        return WorkoutRowData(
            activityId: record.activityId,
            title: record.workoutName ?? record.name,
            dateText: dateText(record.start),
            distanceText: distance.map(distanceText),
            durationText: duration.map(clockText),
            paceText: isRun ? pace(distance: distance, duration: duration).map { "\(clockText($0)) \(WorkoutConstants.paceUnit)" } : nil,
            hasPrescription: record.workoutName != nil
        )
    }

    private static func pace(distance: Double?, duration: Double?) -> Double? {
        guard let distance, let duration else { return nil }
        return duration / (distance / WorkoutConstants.metersPerKilometer)
    }

    private static func distanceText(_ meters: Double) -> String {
        let kilometers = (meters / WorkoutConstants.metersPerKilometer)
            .formatted(.number.precision(.fractionLength(1)).locale(WorkoutConstants.locale))
        return "\(kilometers) \(WorkoutConstants.distanceUnit)"
    }

    private static func clockText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    private static func dateText(_ date: Date) -> String {
        guard date > .distantPast else { return "" }
        return date.formatted(
            .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()
                .locale(WorkoutConstants.locale)
        )
    }
}
