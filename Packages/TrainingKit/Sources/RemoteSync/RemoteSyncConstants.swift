import Foundation

enum RemoteSyncConstants {
    static let syncKeyByteCount = 32
    static let hkdfSalt = Data("trAIning-sync-v1".utf8)
    static let accountInfo = Data("account".utf8)
    static let payloadInfo = Data("payload".utf8)
    static let derivedKeyByteCount = 32
    static let accountPath = "api/v1/account"
    static let changesPath = "api/v1/changes"
    static let watchTokenPath = "api/v1/watch/token"
    static let watchReadinessPath = "api/v1/watch/readiness"
    static let watchVerdictMaxLength = 24
    static let watchScoreRange = 0...100
    static let watchFaceTextMaxLength = 40
    static let watchFaceShapeMaxSteps = 24
    static let watchFaceShapeMaxWeight = 100
    static let watchFaceZoneRange = 1...5
    static let watchFaceVO2DeltaLimit = 20.0
    static let watchFaceWeekKmLimit = 1_000.0
    static let watchFaceRaceSecondsLimit = 2 * 24 * 60 * 60
    static let sinceQuery = "since"
    static let pushBatchSize = 100
    static let quotaExceededCode = "quota_exceeded"
    static let tokenConflictCode = "token_conflict"
    static let maxBatchBodyBytes = 3_500_000
    static let maxPayloadCharacters = 950_000
    static let reducedGPXMaxPoints = 5_000
    static let pushOverlap: TimeInterval = 5
    static let batchEnvelopeBytes = 32
}
