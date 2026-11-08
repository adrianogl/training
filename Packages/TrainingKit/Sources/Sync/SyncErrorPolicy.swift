import GarminAPI

enum SyncErrorPolicy {
    static func isCredentialFailure(_ error: GarminAPIError) -> Bool {
        error == .invalidKey || error == .unauthorized
    }

    static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || Task.isCancelled
    }
}
