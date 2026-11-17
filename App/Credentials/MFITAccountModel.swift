import Foundation
import GarminAPI
import MFIT
import Observation
import TrainingCore

@MainActor @Observable final class MFITAccountModel {
    private typealias C = MFITAccountConstants

    private(set) var isSignedIn: Bool
    private(set) var isWorking = false
    private(set) var message: String?
    private(set) var revision = 0
    @ObservationIgnored private let store: any APIKeyStore
    @ObservationIgnored private let makeTransport: @Sendable () -> any HTTPTransport

    init(store: any APIKeyStore, makeTransport: @escaping @Sendable () -> any HTTPTransport) {
        self.store = store
        self.makeTransport = makeTransport
        self.isSignedIn = ((try? store.read()) ?? nil)?.isEmpty == false
    }

    var client: MFITClient? {
        guard isSignedIn, let token = (try? store.read()) ?? nil, !token.isEmpty else { return nil }
        return MFITClient(token: token, transport: makeTransport())
    }

    func signIn(email: String, password: String) async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let token = try await MFITClient.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, transport: makeTransport())
            try store.save(token)
            isSignedIn = true
            AccountScope.current.defaults.removeObject(forKey: C.teacherCheckedKey)
            await adoptTeacherWithProgram()
            revision += 1
        } catch MFITError.invalidLogin(let text) {
            message = text ?? C.invalidCredentials
        } catch {
            message = C.failed
        }
    }

    func adoptTeacherWithProgram(defaults: UserDefaults = AccountScope.current.defaults) async {
        guard let client, !defaults.bool(forKey: C.teacherCheckedKey) else { return }
        guard let token = try? await client.tokenForActiveTeacher(today: Day.today().iso) else { return }
        if token != client.token { try? store.save(token) }
        defaults.set(true, forKey: C.teacherCheckedKey)
    }

    func reloadFromStore() {
        isSignedIn = ((try? store.read()) ?? nil)?.isEmpty == false
        revision += 1
    }

    func signOut() {
        try? store.delete()
        CredentialSyncStore.recordSignOut(id: DeviceSyncConstants.mfitTokenId, defaults: AccountScope.current.defaults)
        isSignedIn = false
        message = nil
        revision += 1
    }
}
