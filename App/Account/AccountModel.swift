import Foundation
import GarminAPI
import Observation
import RemoteSync
import UIKit

@MainActor @Observable final class AccountModel {
    typealias C = AccountConstants

    private(set) var token: String?
    private(set) var user: AuthUser?
    private(set) var sessions: [AuthSessionInfo] = []
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var webOnly = false

    @ObservationIgnored private let store: any APIKeyStore
    @ObservationIgnored private let transport: any HTTPTransport
    @ObservationIgnored private let baseURL: URL
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let device: String
    @ObservationIgnored var legacyKey: (@MainActor () -> String?)?
    @ObservationIgnored var onSignedIn: (@MainActor (AuthUser) -> Void)?
    @ObservationIgnored var onSignedOut: (@MainActor (AccountSignOut) async -> Void)?

    var isSignedIn: Bool { token != nil }

    init(
        store: any APIKeyStore = KeychainKeyStore(account: AccountConstants.keychainAccount),
        transport: any HTTPTransport,
        baseURL: URL,
        defaults: UserDefaults = .standard,
        device: String = UIDevice.current.model
    ) {
        self.store = store
        self.transport = transport
        self.baseURL = baseURL
        self.defaults = defaults
        self.device = device
        let saved = (try? store.read()) ?? nil
        self.token = saved?.isEmpty == false ? saved : nil
        self.user = defaults.data(forKey: C.userDefaultsKey).flatMap { try? JSONDecoder().decode(AuthUser.self, from: $0) }
    }

    func clearMessages() {
        errorMessage = nil
        notice = nil
        webOnly = false
    }

    func signup(name: String, email: String, password: String) async -> Bool {
        await run {
            let session = try await self.client().signup(
                name: name, email: email, password: password, device: self.device, legacyKey: self.legacyKey?()
            )
            try self.keep(session)
        }
    }

    func login(email: String, password: String) async -> Bool {
        await run {
            try self.keep(try await self.client().login(email: email, password: password, device: self.device))
        }
    }

    func forgotPassword(email: String) async -> Bool {
        await run { try await self.client().forgotPassword(email: email) }
    }

    func refresh() async {
        guard isSignedIn else { return }
        do {
            let client = client()
            let fresh = try await client.me()
            save(user: fresh)
            sessions = try await client.sessions()
        } catch AuthError.unauthorized {
            await forget(deleted: false)
        } catch {
            C.logger.error("Falha ao atualizar a conta: \(String(describing: error), privacy: .public)")
        }
    }

    func rename(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != user?.name else { return }
        _ = await run { self.save(user: try await self.client().rename(trimmed)) }
    }

    func changePassword(current: String, next: String, endOtherSessions: Bool) async -> Bool {
        let changed = await run {
            try await self.client().changePassword(current: current, next: next, endOtherSessions: endOtherSessions)
        }
        if !changed, errorMessage == C.invalidCredentials {
            errorMessage = C.wrongCurrent
        }
        if changed {
            notice = C.passwordChanged
            await refresh()
        }
        return changed
    }

    func resendVerification() async {
        if await run({ try await self.client().resendVerification() }) {
            notice = C.resent
        }
    }

    func endSession(_ id: String) async {
        if await run({ try await self.client().endSession(id: id) }) {
            sessions.removeAll { $0.id == id }
        }
    }

    func signOut() async {
        try? await client().logout()
        await forget(deleted: false)
    }

    func deleteAccount() async -> Bool {
        let deleted = await run { try await self.client().deleteAccount() }
        if deleted { await forget(deleted: true) }
        return deleted
    }

    private func client() -> AuthClient {
        AuthClient(baseURL: baseURL, token: token, transport: transport)
    }

    private func keep(_ session: AuthSession) throws {
        try store.save(session.token)
        token = session.token
        save(user: session.user)
        onSignedIn?(session.user)
    }

    private func save(user: AuthUser) {
        self.user = user
        defaults.set(try? JSONEncoder().encode(user), forKey: C.userDefaultsKey)
    }

    private func forget(deleted: Bool) async {
        let signOut = AccountSignOut(user: user, deleted: deleted)
        try? store.delete()
        defaults.removeObject(forKey: C.userDefaultsKey)
        token = nil
        user = nil
        sessions = []
        await onSignedOut?(signOut)
    }

    private func run(_ work: @escaping @MainActor () async throws -> Void) async -> Bool {
        isWorking = true
        errorMessage = nil
        notice = nil
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch AuthError.webOnly {
            webOnly = true
        } catch let error as AuthError {
            errorMessage = Self.message(for: error)
        } catch {
            C.logger.error("Falha na conta: \(String(describing: error), privacy: .public)")
            errorMessage = (error as? URLError) != nil ? C.offline : C.generic
        }
        return false
    }

    static func message(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials: C.invalidCredentials
        case .emailTaken: C.emailTaken
        case .legacyUnavailable: C.legacyUnavailable
        case .invalidEmail: C.invalidEmail
        case .invalidName: C.invalidName
        case .invalidPassword: C.shortPassword
        case .rateLimited: C.rateLimited
        case .mailUnavailable: C.mailUnavailable
        case .inviteRequired: C.inviteRequired
        case .webOnly: C.webOnlyTitle
        case .invalidToken, .unauthorized, .server, .decoding: C.generic
        }
    }
}
