import TrainingCore

enum WorkoutFilter: CaseIterable, Hashable {
    case all, run, strength, swim

    var title: String {
        switch self {
        case .all: "Todos"
        case .run: "Corrida"
        case .strength: "Força"
        case .swim: "Natação"
        }
    }

    func matches(_ typeKey: String) -> Bool {
        switch self {
        case .all: true
        case .run: ActivityTypeKey.isRun(typeKey)
        case .strength: WorkoutConstants.strengthTypeKeys.contains(typeKey)
        case .swim: typeKey.hasSuffix(WorkoutConstants.swimSuffix)
        }
    }
}
