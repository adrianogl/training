public enum RemoteSyncError: Error, Equatable {
    case invalidSyncKey
    case tamperedPayload
    case unauthorized
    case rateLimited
    case badRequest
    case payloadTooLarge
    case quotaExceeded
    case server(status: Int)
    case unexpectedStatus(Int)
    case decoding
}
