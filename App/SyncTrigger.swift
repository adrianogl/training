enum SyncTrigger: Equatable {
    case launch
    case pull
    case settings
    case background
    case workoutFinished

    var runsInBackground: Bool { self == .background || self == .workoutFinished }

    func runsAfter(_ running: SyncTrigger?) -> Bool {
        switch self {
        case .settings: running != .settings
        case .launch, .pull: running == .workoutFinished
        case .background, .workoutFinished: false
        }
    }
}
