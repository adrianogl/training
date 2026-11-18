import Foundation
import Observation
import RemoteSync

@MainActor @Observable final class InvitesModel {
    private(set) var snapshot: AdminSnapshot?
    private(set) var isWorking = false
    private(set) var errorMessage: String?
    var delivery: InviteDelivery?

    @ObservationIgnored private let client: @MainActor () -> AdminClient?

    init(client: @escaping @MainActor () -> AdminClient?) {
        self.client = client
    }

    func load() async {
        _ = await run { client in self.snapshot = try await client.snapshot() }
    }

    func create(name: String, channel: InviteChannel, email: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return await deliver { try await $0.createInvite(name: name.trimmingCharacters(in: .whitespacesAndNewlines), channel: channel, email: trimmedEmail.isEmpty ? nil : trimmedEmail) }
    }

    func renew(_ invite: AdminInvite) async {
        _ = await deliver { try await $0.renewInvite(id: invite.id) }
    }

    func invite(_ request: AdminInviteRequest) async {
        _ = await deliver { try await $0.inviteFromRequest(id: request.id) }
    }

    func cancel(_ invite: AdminInvite) async {
        if await run({ try await $0.cancelInvite(id: invite.id) }) { await load() }
    }

    func decline(_ request: AdminInviteRequest) async {
        if await run({ try await $0.declineRequest(id: request.id) }) { await load() }
    }

    func remove(_ user: AdminUser) async {
        if await run({ try await $0.deleteUser(id: user.id) }) { await load() }
    }

    private func deliver(_ work: @escaping (AdminClient) async throws -> InviteDelivery) async -> Bool {
        var result: InviteDelivery?
        guard await run({ result = try await work($0) }) else { return false }
        delivery = result
        await load()
        return true
    }

    private func run(_ work: @escaping (AdminClient) async throws -> Void) async -> Bool {
        guard let client = client() else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await work(client)
            return true
        } catch let error as AuthError {
            errorMessage = AccountModel.message(for: error)
        } catch {
            errorMessage = (error as? URLError) != nil ? AccountConstants.offline : AccountConstants.generic
        }
        return false
    }
}
