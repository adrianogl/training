import GarminAPI

enum GarminAccountPhase: Equatable {
    case idle
    case working
    case needsCode(GarminMFAChallenge)
}
