enum SyncTrigger: Equatable {
    case launch
    case pull
    case settings
    case background
    case workoutFinished

    var runsInBackground: Bool { self == .background || self == .workoutFinished }
}
