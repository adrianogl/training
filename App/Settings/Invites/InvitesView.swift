import RemoteSync
import SwiftUI

struct InvitesView: View {
    @State private var model: InvitesModel
    @State private var showsNew = false
    @State private var removing: AdminUser?

    private typealias C = InvitesConstants

    init(account: AccountModel) {
        _model = State(initialValue: InvitesModel(client: { account.adminClient() }))
    }

    var body: some View {
        Group {
            Section {
                counters
                Button(C.newInvite) { showsNew = true }
                    .font(.headline)
            } footer: {
                AccountMessage(error: model.errorMessage, notice: nil)
            }
            if let snapshot = model.snapshot {
                requests(snapshot.requests)
                invites(snapshot.invites)
                people(snapshot.users)
            }
        }
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(isPresented: $showsNew) { NewInviteSheet(model: model) }
        .sheet(item: $model.delivery) { delivery in InviteDeliverySheet(delivery: delivery) }
        .confirmationDialog(
            String(format: C.removeTitle, removing?.name ?? ""),
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            Button(C.removeAction, role: .destructive) {
                if let user = removing { Task { await model.remove(user) } }
            }
            Button(C.keep, role: .cancel) {}
        } message: {
            Text(C.removeText)
        }
    }

    private var counters: some View {
        let overview = model.snapshot?.overview
        let requests = model.snapshot?.requests.count ?? 0
        return HStack(spacing: 8) {
            counter("\(overview?.accounts ?? 0)/\(overview?.maxAccounts ?? 0)", C.accounts, tint: BrandColors.text)
            counter("\(overview?.pendingInvites ?? 0)", C.pending, tint: BrandColors.text)
            counter("\(requests)", requests == 1 ? C.requestOne : C.requestMany, tint: requests > 0 ? BrandColors.attention : BrandColors.text)
        }
        .redacted(reason: model.snapshot == nil ? .placeholder : [])
    }

    private func counter(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(BrandFonts.number(20)).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12))
    }

    private func requests(_ items: [AdminInviteRequest]) -> some View {
        Section(C.requestsTitle) {
            if items.isEmpty {
                Text(C.noRequests).foregroundStyle(BrandColors.dim)
            }
            ForEach(items) { request in
                VStack(alignment: .leading, spacing: 8) {
                    Text(request.name).font(.body.weight(.semibold))
                    Text([request.email, request.watch, InvitesText.relative(request.createdAt)].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(BrandColors.dim)
                    if !request.message.isEmpty {
                        Text("“\(request.message)”").font(.subheadline).foregroundStyle(BrandColors.dim)
                    }
                    HStack {
                        Button(C.inviteAction) { Task { await model.invite(request) } }
                            .buttonStyle(.ds(.primary))
                        Button(C.declineAction) { Task { await model.decline(request) } }
                            .buttonStyle(.ds(.secondary))
                    }
                    .disabled(model.isWorking)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func invites(_ items: [AdminInvite]) -> some View {
        Section(C.invitesTitle) {
            if items.isEmpty {
                Text(C.noInvites).foregroundStyle(BrandColors.dim)
            }
            ForEach(items) { invite in
                Menu {
                    if invite.status != .accepted {
                        Button(C.renewAction) { Task { await model.renew(invite) } }
                    }
                    if invite.status == .pending {
                        Button(C.cancelAction, role: .destructive) { Task { await model.cancel(invite) } }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invite.name).font(.body.weight(.semibold)).foregroundStyle(BrandColors.text)
                            Text("\(invite.channel.title) · \(InvitesText.detail(invite))").font(.caption).foregroundStyle(BrandColors.dim)
                        }
                        Spacer()
                        Text(InvitesText.status(invite.status))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(InvitesText.tint(invite.status))
                    }
                }
                .disabled(invite.status == .accepted)
            }
        }
    }

    private func people(_ users: [AdminUser]) -> some View {
        Section(C.peopleTitle) {
            ForEach(users) { user in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.admin ? "\(user.name) · \(C.adminBadge)" : user.name).font(.body.weight(.semibold))
                        Text(InvitesText.person(user)).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    Spacer()
                    if !user.admin {
                        Button(C.removeAction, role: .destructive) { removing = user }
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}
