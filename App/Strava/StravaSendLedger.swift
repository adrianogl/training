import Foundation

enum StravaSendStatus: String, Codable, Equatable, Sendable {
    case sent, pending, editedByUser
}

struct StravaSendEntry: Codable, Equatable, Sendable {
    var status: StravaSendStatus
    var firstAttempt: Date
    var nextAttempt: Date
    var sentAt: Date?
}

struct StravaSendLedger: Codable, Equatable, Sendable {
    private(set) var entries: [Int64: StravaSendEntry] = [:]

    private typealias C = StravaConstants

    func entry(_ activityId: Int64) -> StravaSendEntry? {
        entries[activityId]
    }

    func isSent(_ activityId: Int64) -> Bool {
        entries[activityId]?.status == .sent
    }

    func shouldAttempt(_ activityId: Int64, runStart: Date, now: Date) -> Bool {
        guard now.timeIntervalSince(runStart) <= C.retryWindow else { return false }
        guard let entry = entries[activityId] else { return true }
        return entry.status == .pending && entry.nextAttempt <= now
    }

    mutating func record(_ outcome: StravaSendOutcome, activityId: Int64, now: Date) {
        let first = entries[activityId]?.firstAttempt ?? now
        switch outcome {
        case .posted, .updated:
            entries[activityId] = StravaSendEntry(status: .sent, firstAttempt: first, nextAttempt: now, sentAt: now)
        case .editedByUser:
            entries[activityId] = StravaSendEntry(status: .editedByUser, firstAttempt: first, nextAttempt: now, sentAt: entries[activityId]?.sentAt)
        case .notFound, .retryLater:
            entries[activityId] = StravaSendEntry(status: .pending, firstAttempt: first, nextAttempt: now.addingTimeInterval(C.retryDelay), sentAt: entries[activityId]?.sentAt)
        case .disabled:
            entries[activityId] = nil
        }
        trim()
    }

    private mutating func trim() {
        guard entries.count > C.ledgerLimit else { return }
        let kept = entries.sorted { $0.value.firstAttempt > $1.value.firstAttempt }.prefix(C.ledgerLimit)
        entries = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
    }
}

enum StravaSendOutcome: Equatable, Sendable {
    case posted, updated, notFound, editedByUser, disabled, retryLater
}
