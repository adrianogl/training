enum BrandRefreshPhase: Equatable {
    case idle
    case pulling
    case syncing
    case done
}

enum BrandRefreshEvent: Equatable {
    case started
    case cancelled
}
