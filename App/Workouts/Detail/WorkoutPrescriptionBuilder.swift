import Foundation
import Insights

enum WorkoutPrescriptionBuilder {
    private typealias T = WorkoutPrescriptionText

    static func prescription(row: TrainerDayRow?, activityId: Int64, isRun: Bool, doneMeters: Double?) -> WorkoutPrescription? {
        guard isRun, let row, row.run?.activityId == activityId, row.workout.kind != .off else { return nil }
        let workout = row.workout
        var numbers = [WorkoutPrescriptionNumber(value: TrainerText.distance(workout.totalMeters), label: T.plannedLabel)]
        if let pace = TrainerText.paceRange(low: workout.paceLow, high: workout.paceHigh) {
            numbers.append(WorkoutPrescriptionNumber(value: pace, label: hasReps(workout.kind) ? T.repsPaceLabel : T.paceLabel))
        }
        if let doneMeters, doneMeters > 0 {
            numbers.append(WorkoutPrescriptionNumber(value: TrainerText.distance(doneMeters), label: T.doneLabel))
        }
        let rationale = workout.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        return WorkoutPrescription(
            iso: workout.day.iso,
            workout: workout,
            numbers: numbers,
            rationale: rationale.isEmpty ? nil : rationale,
            methodLine: workout.method.map(TrainerText.methodLine)
        )
    }

    private static func hasReps(_ kind: TrainerDayKind) -> Bool {
        kind == .threshold || kind == .vo2max
    }
}
