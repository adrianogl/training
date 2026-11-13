import Foundation
import GarminAPI
import Observation

@MainActor @Observable final class GarminAccountModel {
    private typealias C = GarminAccountConstants

    private(set) var isSignedIn: Bool
    private(set) var phase = GarminAccountPhase.idle
    private(set) var message: String?
    @ObservationIgnored private let store: KeychainGarminSessionStore
    @ObservationIgnored private let makeTransport: @Sendable () -> any HTTPTransport
    @ObservationIgnored private var pending: GarminAccountAuth?

    init(store: KeychainGarminSessionStore, makeTransport: @escaping @Sendable () -> any HTTPTransport) {
        self.store = store
        self.makeTransport = makeTransport
        self.isSignedIn = ((try? store.load()) ?? nil) != nil
    }

    var client: GarminAccountClient? {
        isSignedIn ? GarminAccountClient(transport: makeTransport(), store: store) : nil
    }

    func signIn(email: String, password: String) async {
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
        guard case .needsCode(let challenge) = phase, let pending else { return }
        phase = .working
        do {
            finish(try await pending.verify(code: code.trimmingCharacters(in: .whitespacesAndNewlines), challenge: challenge))
        } catch {
            phase = .needsCode(challenge)
            message = Self.text(for: error)
        }
    }

    func signOut() {
        try? store.delete()
        isSignedIn = false
        phase = .idle
        message = nil
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
        switch error as? GarminAccountError {
        case .invalidCredentials: C.invalidCredentials
        case .invalidCode: C.invalidCode
        case .rateLimited: C.rateLimited
        default: C.failed
        }
    }
}
