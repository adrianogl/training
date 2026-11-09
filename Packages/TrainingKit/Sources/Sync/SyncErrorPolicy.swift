import GarminAPI

enum SyncErrorPolicy {
    static func isCredentialFailure(_ error: GarminAPIError) -> Bool {
        error == .invalidKey || error == .unauthorized
    }

    static func isPermanentFITFailure(_ error: GarminAPIError) -> Bool {
        guard case let .client(status, _) = error else { return false }
        return SyncConstants.missingFITStatuses.contains(status)
    }

    static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || Task.isCancelled
    }
}
