import Foundation
import GarminAPI
import Observation
import RemoteSync

@MainActor @Observable final class GarminAccountModel {
    private typealias C = GarminAccountConstants

    private(set) var isSignedIn: Bool
    private(set) var phase = GarminAccountPhase.idle
    private(set) var message: String?
    @ObservationIgnored private let store: KeychainGarminSessionStore
    @ObservationIgnored private let makeTransport: @Sendable () -> any HTTPTransport
    @ObservationIgnored private var pending: GarminAccountAuth?
    @ObservationIgnored var link: (@MainActor () -> GarminLinkClient?)?

    init(store: KeychainGarminSessionStore, makeTransport: @escaping @Sendable () -> any HTTPTransport) {
        self.store = store
        self.makeTransport = makeTransport
        self.isSignedIn = ((try? store.load()) ?? nil) != nil
    }

    var client: GarminAccountClient? {
        guard isSignedIn else { return nil }
        guard let link = link?() else { return GarminAccountClient(transport: makeTransport(), store: store) }
        return GarminAccountClient(transport: makeTransport(), store: store, refresher: { _ in try await link.session() })
    }

    func adoptAccountSession() async {
        guard !isSignedIn, let link = link?() else { return }
        guard let session = try? await link.session() else { return }
        finish(session)
    }

    func signIn(email: String, password: String) async {
        if let link = link?() {
            await signInThroughAccount(link, email: email, password: password)
            return
        }
        let auth = GarminAccountAuth(transport: makeTransport())
        pending = auth
        phase = .working
        message = nil
        do {
            switch try await auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) {
            case .signedIn(let session):
                finish(session)
            case .needsCode(let challenge):
                phase = .needsCode(challenge)
                message = String(format: C.codeSentFormat, C.methodNames[challenge.method] ?? challenge.method)
            }
        } catch {
            fail(error)
        }
    }

    func verify(code: String) async {
        guard case .needsCode(let challenge) = phase else { return }
        if let link = link?() {
            phase = .working
            do {
                _ = try await link.verify(code: code.trimmingCharacters(in: .whitespacesAndNewlines))
                finish(try await link.session())
            } catch {
                phase = error as? GarminLinkError == .loginExpired ? .idle : .needsCode(challenge)
                message = Self.text(for: error)
            }
            return
        }
        guard let pending else { return }
        phase = .working
        do {
            finish(try await pending.verify(code: code.trimmingCharacters(in: .whitespacesAndNewlines), challenge: challenge))
        } catch {
            phase = .needsCode(challenge)
            message = Self.text(for: error)
        }
    }

    func signOut() {
        if let link = link?() {
            Task { try? await link.disconnect() }
        }
        forgetLocal()
    }

    func forgetLocal() {
        try? store.delete()
        isSignedIn = false
        phase = .idle
        message = nil
    }

    private func signInThroughAccount(_ link: GarminLinkClient, email: String, password: String) async {
        phase = .working
        message = nil
        do {
            switch try await link.connect(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) {
            case .connected:
                finish(try await link.session())
            case .needsCode(let method):
                phase = .needsCode(GarminMFAChallenge(method: method))
                message = String(format: C.codeSentFormat, C.methodNames[method] ?? method)
            }
        } catch {
            fail(error)
        }
    }

    private func finish(_ session: GarminAccountSession) {
        do {
            try store.save(session)
            isSignedIn = true
            message = nil
        } catch {
            message = C.failed
        }
        phase = .idle
        pending = nil
    }

    private func fail(_ error: Error) {
        phase = .idle
        pending = nil
        message = Self.text(for: error)
    }

    private static func text(for error: Error) -> String {
        if let linkError = error as? GarminLinkError {
            return switch linkError {
            case .invalidCredentials: C.invalidCredentials
            case .invalidCode: C.invalidCode
            case .rateLimited: C.rateLimited
            case .loginExpired: C.loginExpired
            default: C.failed
            }
        }
        return switch error as? GarminAccountError {
        case .invalidCredentials: C.invalidCredentials
        case .invalidCode: C.invalidCode
        case .rateLimited: C.rateLimited
        default: C.failed
        }
    }
}
