import AuthenticationServices
import Foundation
import Observation
import RemoteSync
import Storage
import SwiftData
import TrainingCore

@MainActor @Observable final class StravaModel {
    private typealias C = StravaConstants

    private(set) var status = StravaStatus.disconnected
    private(set) var phase = StravaPhase.idle
    private(set) var message: String?
    private(set) var ledger: StravaSendLedger
    @ObservationIgnored var link: (@MainActor () -> StravaClient?)?
    @ObservationIgnored var connectionChanged: (@MainActor (Bool) async -> Void)?
    @ObservationIgnored var imported: (@MainActor (Set<Int64>) async -> Void)?
    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored let defaults: UserDefaults
    @ObservationIgnored private let authenticator: any StravaWebAuthenticating
    @ObservationIgnored let now: @Sendable () -> Date
    @ObservationIgnored private var passRunning = false

    init(
        container: ModelContainer,
        defaults: UserDefaults = AccountScope.current.defaults,
        authenticator: any StravaWebAuthenticating = StravaWebAuthenticator(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.container = container
        self.defaults = defaults
        self.authenticator = authenticator
        self.now = now
        self.ledger = Self.storedLedger(defaults)
    }

    var isConnected: Bool { status.connected }

    func handles(_ url: URL) -> Bool {
        url.scheme == C.callbackScheme && url.host() == "strava"
    }

    func refreshStatus() async {
        guard let client = link?() else { return }
        do {
            status = try await client.status()
            message = nil
            if status.connected { await connectionChanged?(true) }
        } catch StravaLinkError.notConfigured {
            message = C.unavailable
        } catch {
            if status.connected { message = C.statusFailed }
        }
    }

    func connect() async {
        guard let client = link?() else { return }
        phase = .working
        message = nil
        defer { phase = .idle }
        do {
            let callback = try await authenticator.authenticate(url: try await client.connectURL())
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            switch items.first(where: { $0.name == "error" })?.value {
            case nil: await refreshStatus()
            case "access_denied": message = C.connectDenied
            case "scope": message = C.connectScope
            default: message = C.connectFailed
            }
        } catch StravaLinkError.notConfigured {
            message = C.unavailable
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            message = nil
        } catch {
            message = C.connectFailed
        }
    }

    func setEnabled(_ enabled: Bool) async {
        guard let client = link?() else { return }
        do {
            status = try await client.setEnabled(enabled)
            message = nil
        } catch {
            message = C.statusFailed
        }
    }

    func disconnect() async {
        guard let client = link?() else { return }
        phase = .working
        defer { phase = .idle }
        do {
            try await client.disconnect()
            status = .disconnected
            message = nil
        } catch {
            message = C.statusFailed
        }
    }

    func send(activityId: Int64) async -> StravaSendResult {
        guard status.connected, let client = link?() else { return .notConnected }
        let container = container
        let payload = await Task.detached(priority: .utility) {
            StravaSummaryLoader.payload(activityId: activityId, in: ModelContext(container))
        }.value
        guard let payload else { return .noText }
        let result = await describe(payload, client: client)
        return result
    }

    func sendPending() async {
        guard status.connected, status.enabled, !passRunning, let client = link?() else { return }
        passRunning = true
        defer { passRunning = false }
        ledger = Self.storedLedger(defaults)
        let current = now()
        let container = container
        let recent = await Task.detached(priority: .utility) { Self.recentRuns(in: ModelContext(container), since: current.addingTimeInterval(-C.retryWindow)) }.value
        let due = recent.filter { ledger.shouldAttempt($0.id, runStart: $0.start, now: current) }.prefix(C.maxPerPass)
        for run in due {
            let payload = await Task.detached(priority: .utility) {
                StravaSummaryLoader.payload(activityId: run.id, in: ModelContext(container))
            }.value
            guard let payload, payload.scored else { continue }
            let result = await describe(payload, client: client)
            if result == .failed || result == .retryLater || result == .disabled || result == .notConnected { break }
        }
    }

    private func describe(_ payload: StravaPayload, client: StravaClient) async -> StravaSendResult {
        let request = StravaDescribeRequest(
            activityId: String(payload.activityId),
            startTime: payload.start,
            elapsedSeconds: payload.elapsedSeconds,
            distanceMeters: payload.distanceMeters,
            text: payload.text
        )
        do {
            let outcome = try await client.describe(request)
            return apply(outcome, activityId: payload.activityId)
        } catch StravaLinkError.notConnected {
            status = .disconnected
            return .notConnected
        } catch StravaLinkError.sessionExpired {
            status = .disconnected
            await connectionChanged?(false)
            return .notConnected
        } catch {
            return .failed
        }
    }

    func apply(_ outcome: StravaDescribeOutcome, activityId: Int64) -> StravaSendResult {
        let mapped: StravaSendOutcome
        let result: StravaSendResult
        switch outcome {
        case .posted: (mapped, result) = (.posted, .posted)
        case .updated: (mapped, result) = (.updated, .updated)
        case .notFound: (mapped, result) = (.notFound, .notYet)
        case .editedByUser: (mapped, result) = (.editedByUser, .editedByUser)
        case .disabled: (mapped, result) = (.disabled, .disabled)
        case .retryLater: (mapped, result) = (.retryLater, .retryLater)
        }
        ledger = Self.storedLedger(defaults)
        ledger.record(mapped, activityId: activityId, now: now())
        if let data = try? JSONEncoder().encode(ledger) { defaults.set(data, forKey: C.ledgerDefaultsKey) }
        return result
    }

    private static func storedLedger(_ defaults: UserDefaults) -> StravaSendLedger {
        defaults.data(forKey: C.ledgerDefaultsKey).flatMap { try? JSONDecoder().decode(StravaSendLedger.self, from: $0) } ?? StravaSendLedger()
    }

    nonisolated private static func recentRuns(in context: ModelContext, since: Date) -> [(id: Int64, start: Date)] {
        let descriptor = FetchDescriptor<ActivityRecord>(predicate: #Predicate { $0.start >= since && $0.fitProcessed }, sortBy: [SortDescriptor(\.start, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).filter { ActivityTypeKey.isRun($0.typeKey) }.map { ($0.activityId, $0.start) }
    }
}
