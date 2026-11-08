import GarminAPI

enum SyncErrorPolicy {
    static func isCredentialFailure(_ error: GarminAPIError) -> Bool {
        error == .invalidKey || error == .unauthorized
    }
}
