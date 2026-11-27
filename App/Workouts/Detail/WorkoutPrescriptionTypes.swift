import Insights

struct WorkoutPrescription: Equatable {
    let iso: String
    let workout: TrainerWorkout
    let numbers: [WorkoutPrescriptionNumber]
    let rationale: String?
    let methodLine: String?
}

struct WorkoutPrescriptionNumber: Equatable, Identifiable {
    let value: String
    let label: String

    var id: String { label }
}
