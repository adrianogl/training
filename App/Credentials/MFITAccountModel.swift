import Foundation
import GarminAPI
import MFIT
import Observation

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
            await adoptTeacherWithProgram()
            revision += 1
        } catch MFITError.invalidLogin(let text) {
            message = text ?? C.invalidCredentials
        } catch {
            message = C.failed
        }
    }

    func adoptTeacherWithProgram() async {
        guard let client, (try? await client.hasPrograms()) == false else { return }
        for teacher in (try? await client.teachers()) ?? [] {
            guard let token = try? await client.switchTeacher(teacher.id) else { continue }
            let candidate = MFITClient(token: token, transport: makeTransport())
            guard (try? await candidate.hasPrograms()) == true else { continue }
            try? store.save(token)
            return
        }
    }

    func signOut() {
        try? store.delete()
        isSignedIn = false
        message = nil
        revision += 1
    }
}
