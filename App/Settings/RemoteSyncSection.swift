import SwiftUI

struct RemoteSyncSection: View {
    typealias C = RemoteSyncSettingsConstants
    let model: RemoteSyncModel
    @State private var revealedKey: String?
    @State private var confirmsDisable = false
    @State private var confirmsDelete = false
    @State private var pastes = false

    var body: some View {
        if model.isEnabled {
            enabledSections
        } else {
            disabledSection
        }
    }

    private var disabledSection: some View {
        Section {
            Text(C.offDescription)
                .foregroundStyle(BrandColors.dim)
            Button {
                Task { await model.activate() }
            } label: {
                Text(model.isWorking ? C.activating : C.activate)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(BrandColors.onAccent)
            .disabled(model.isWorking)
            Button(C.haveKey) { pastes = true }
                .frame(maxWidth: .infinity)
                .disabled(model.isWorking)
            if let message = model.actionMessage {
                Text(message).font(.footnote).foregroundStyle(BrandColors.danger)
            }
        } header: {
            Text(C.sectionTitle)
        } footer: {
            Text(C.privacyNote)
        }
        .navigationDestination(isPresented: $pastes) {
            RemoteSyncPasteView(model: model)
        }
    }

    @ViewBuilder
    private var enabledSections: some View {
        let counts = model.localCounts()
        Section(C.sectionTitle) {
            LabeledContent {
                Text(statusDetail).foregroundStyle(BrandColors.dim)
            } label: {
                Label {
                    Text(statusTitle)
                } icon: {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                }
            }
            LabeledContent(C.racesLabel, value: "\(counts.races)")
            LabeledContent(C.decisionsLabel, value: "\(counts.decisions)")
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
        }
        Section {
            if let revealedKey {
                Text(revealedKey)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button(C.hideKey) { self.revealedKey = nil }
            } else {
                Button {
                    Task { revealedKey = await model.revealKey(reason: C.revealReason) }
                } label: {
                    LabeledContent(C.showKey, value: C.showKeyHint)
                }
            }
            Button(C.copyKey) {
                Task { await model.copyKey() }
            }
            if let message = model.keyMessage {
                Text(message).font(.footnote).foregroundStyle(BrandColors.dim)
            }
        } header: {
            Text(C.keySectionTitle)
        } footer: {
            Text(C.keyNote)
        }
        Section {
            Button(C.disable, role: .destructive) { confirmsDisable = true }
                .disabled(model.status == .syncing || model.isWorking)
                .confirmationDialog(C.disableTitle, isPresented: $confirmsDisable, titleVisibility: .visible) {
                    Button(C.disable, role: .destructive) { Task { await model.disable() } }
                    Button(C.cancel, role: .cancel) {}
                } message: {
                    Text(C.disableMessage)
                }
            Button(C.deleteServer, role: .destructive) { confirmsDelete = true }
                .disabled(model.status == .syncing || model.isWorking)
                .confirmationDialog(C.deleteServerTitle, isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button(C.deleteServerConfirm, role: .destructive) {
                        Task { await model.deleteServerData() }
                    }
                    Button(C.cancel, role: .cancel) {}
                } message: {
                    Text(C.deleteServerMessage)
                }
            if let message = model.actionMessage {
                Text(message).font(.footnote).foregroundStyle(BrandColors.danger)
            }
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
