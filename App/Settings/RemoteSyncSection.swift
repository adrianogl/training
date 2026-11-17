import SwiftUI

struct RemoteSyncSection: View {
    typealias C = RemoteSyncSettingsConstants
    let model: RemoteSyncModel
    var part = RemoteSyncPart.sync
    @State private var revealedWatchToken: String?
    @State private var confirmsRegenerate = false
    @State private var confirmsRevoke = false

    var body: some View {
        switch part {
        case .sync:
            accountSection
        case .watch:
            if model.isEnabled {
                watchSection
            } else {
                Section {
                    Text(C.watchNeedsSync).foregroundStyle(BrandColors.dim)
                }
            }
        }
    }

    private var accountSection: some View {
        Section {
            LabeledContent {
                Text(statusDetail).foregroundStyle(BrandColors.dim)
            } label: {
                Label {
                    Text(statusTitle)
                } icon: {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                }
            }
            if model.status == .failed(.quotaExceeded) {
                Text(C.quotaHint).font(.footnote).foregroundStyle(BrandColors.danger)
            }
            if model.tooLarge > 0 {
                Text(C.tooLarge(model.tooLarge)).font(.footnote).foregroundStyle(BrandColors.attention)
            }
            Button(C.syncNow) {
                Task { await model.syncNow() }
            }
            .disabled(model.status == .syncing)
        } header: {
            Text(C.sectionTitle)
        } footer: {
            Text(C.accountNote)
        }
    }

    private var watchSection: some View {
        Section {
            if model.hasWatchToken {
                if let revealedWatchToken {
                    Text(revealedWatchToken)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                    Button(C.watchHide) { self.revealedWatchToken = nil }
                } else {
                    Button {
                        Task { revealedWatchToken = await model.revealWatchToken() }
                    } label: {
                        LabeledContent(C.watchShow, value: C.showKeyHint)
                    }
                }
                Button(C.watchCopy) {
                    Task { await model.copyWatchToken() }
                }
                WatchCalendarRow()
                Button(C.watchRegenerate) { confirmsRegenerate = true }
                    .disabled(model.isWorking)
                    .confirmationDialog(C.watchRegenerateTitle, isPresented: $confirmsRegenerate, titleVisibility: .visible) {
                        Button(C.watchRegenerate, role: .destructive) {
                            revealedWatchToken = nil
                            Task { await model.generateWatchToken() }
                        }
                        Button(C.cancel, role: .cancel) {}
                    } message: {
                        Text(C.watchRegenerateMessage)
                    }
                Button(C.watchRevoke, role: .destructive) { confirmsRevoke = true }
                    .disabled(model.isWorking)
                    .confirmationDialog(C.watchRevokeTitle, isPresented: $confirmsRevoke, titleVisibility: .visible) {
                        Button(C.watchRevoke, role: .destructive) {
                            revealedWatchToken = nil
                            Task { await model.revokeWatchToken() }
                        }
                        Button(C.cancel, role: .cancel) {}
                    } message: {
                        Text(C.watchRevokeMessage)
                    }
            } else {
                Text(C.watchOffDescription)
                    .foregroundStyle(BrandColors.dim)
                Button(model.isWorking ? C.watchGenerating : C.watchGenerate) {
                    Task { await model.generateWatchToken() }
                }
                .disabled(model.isWorking)
            }
            if let message = model.watchMessage {
                Text(message).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            if let error = model.watchError {
                Text(error).font(.footnote).foregroundStyle(BrandColors.danger)
            }
        } header: {
            Text(C.watchSectionTitle)
        } footer: {
            Text(C.watchNote)
        }
    }

    private var statusTitle: String {
        switch model.status {
        case .off, .idle: C.synced
        case .syncing: C.syncing
        case .waitingForNetwork(let pending): C.waiting(pending)
        case .failed(let problem): C.problem(problem)
        }
    }

    private var statusDetail: String {
        guard model.status == .idle else { return "" }
        guard let lastSync = model.lastSync else { return C.neverSynced }
        return C.relative(lastSync)
    }

    private var statusColor: Color {
        switch model.status {
        case .off, .idle: BrandColors.accent
        case .syncing: BrandColors.dim
        case .waitingForNetwork: BrandColors.attention
        case .failed: BrandColors.danger
        }
    }
}
