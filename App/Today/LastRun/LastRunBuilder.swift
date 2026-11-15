import Foundation
import Storage
import TrainingCore
import WorkoutAnalysis

enum LastRunBuilder {
    private typealias C = LastRunConstants

    static func kind(of record: ActivityRecord) -> SessionKind {
        SessionKind(run: classifyRun(record, longGoalKm: nil, raceGoalKms: []))
    }

    static func similar(to record: ActivityRecord, among records: [ActivityRecord]) -> [ActivityRecord] {
        let kind = kind(of: record)
        let earliest = record.start.addingTimeInterval(-C.windowDays * C.secondsPerDay)
        return records
            .filter {
                ActivityTypeKey.isRun($0.typeKey) && $0.activityId != record.activityId
                    && $0.start < record.start && $0.start >= earliest && Self.kind(of: $0) == kind
            }
            .sorted { $0.start > $1.start }
            .prefix(C.maxSimilar)
            .map { $0 }
    }

    static func paceSeconds(_ record: ActivityRecord) -> Double? {
        guard let meters = record.distance, meters > 0, let seconds = record.movingDuration ?? record.duration else { return nil }
        return seconds / (meters / WorkoutConstants.metersPerKilometer)
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = C.shortDateFormat
        return formatter.string(from: date)
    }

    static func isHeartRateHigh(current: Double?, similar: [Double]) -> Bool {
        guard let current, !similar.isEmpty else { return false }
        return current >= similar.reduce(0, +) / Double(similar.count) + C.heartRateHighDelta
    }

    static func chart(_ splits: [LastRunSplit]) -> LastRunChartData {
        func normalize(_ values: [(Int, Double)], inverted: Bool) -> [LastRunChartPoint] {
            guard let low = values.map(\.1).min(), let high = values.map(\.1).max() else { return [] }
            let span = high - low
            return values.map { km, value in
                let share = span > 0 ? (value - low) / span : 0.5
                return LastRunChartPoint(km: km, value: inverted ? 1 - share : share)
            }
        }
        return LastRunChartData(
            pace: normalize(splits.map { ($0.km, $0.paceSeconds) }, inverted: true),
            heartRate: normalize(splits.compactMap { split in split.heartRate.map { (split.km, $0) } }, inverted: false)
        )
    }

    static func duration(seconds: Double?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        let minutes = Int((seconds / C.secondsPerMinute).rounded())
        guard minutes >= C.minutesPerHour else { return String(format: C.minutesFormat, minutes) }
        return String(format: C.hoursMinutesFormat, minutes / C.minutesPerHour, minutes % C.minutesPerHour)
    }

    static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutConstants.locale
        formatter.dateFormat = C.dateFormat
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    static func reading(
        kind: SessionKind,
        paceSeconds: Double?,
        averageHeartRate: Int?,
        fadeKm: Int?,
        readiness: Int?,
        reference: LastRunReference?
    ) -> String? {
        guard let reference, let paceSeconds, let referencePace = reference.paceSeconds else { return nil }
        let name = C.kindNames[kind] ?? ""
        let delta = Int((paceSeconds - referencePace).rounded())
        var text: String
        if abs(Double(delta)) <= C.paceSameSeconds {
            text = String(format: C.samePaceFormat, name, reference.dateText)
        } else if delta < 0 {
            text = String(format: C.fasterFormat, -delta, name, reference.dateText)
        } else {
            text = String(format: C.slowerFormat, delta, name, reference.dateText)
        }
        if let heartRate = averageHeartRate, let referenceHeartRate = reference.averageHeartRate {
            let difference = heartRate - referenceHeartRate
            if Double(difference) >= C.heartRateSameDelta {
                text += String(format: C.heartRateHigher, difference)
            } else if Double(-difference) >= C.heartRateSameDelta {
                text += String(format: C.heartRateLower, -difference)
            } else {
                text += C.heartRateSame
            }
        }
        if let fadeKm { text += String(format: C.fadeReading, fadeKm) }
        text += "."
        if let readiness, readiness < C.readinessLow { text += String(format: C.readinessFormat, readiness) }
        return text
    }
}
