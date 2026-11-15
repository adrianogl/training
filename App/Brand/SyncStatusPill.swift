import SwiftUI

struct SyncStatusPill: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(BrandRefreshCoordinator.self) private var refresh: BrandRefreshCoordinator?
    @State private var showsFinished = false

    var body: some View {
        let content = refresh?.state.isActive == true ? nil : SyncStatusPillText.content(for: model.syncStatus, showsFinished: showsFinished)
        Group {
            if let content {
                pill(content)
                    .padding(.bottom, SyncStatusPillConstants.bottomPadding)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: SyncStatusPillConstants.fadeSeconds), value: content)
        .task(id: model.syncStatus) { await trackFinished() }
    }

    @ViewBuilder
    private func pill(_ content: SyncStatusPillContent) -> some View {
        if content.kind == .failed {
            Button { Task { await model.syncNow(.pull) } } label: { label(content) }
                .buttonStyle(.plain)
        } else {
            label(content)
        }
    }

    private func label(_ content: SyncStatusPillContent) -> some View {
        HStack(spacing: SyncStatusPillConstants.spacing) {
            icon(content.kind)
            Text(content.text)
                .font(.caption.weight(.medium))
                .foregroundStyle(content.kind == .failed ? BrandColors.danger : BrandColors.dim)
        }
        .padding(.horizontal, SyncStatusPillConstants.horizontalPadding)
        .padding(.vertical, SyncStatusPillConstants.verticalPadding)
        .background(BrandColors.card, in: Capsule())
        .overlay(Capsule().strokeBorder(BrandColors.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func icon(_ kind: SyncStatusPillKind) -> some View {
        switch kind {
        case .syncing:
            BrandLoader(size: .mini)
        case .updated:
            Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(BrandColors.accent)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(BrandColors.danger)
        }
    }

    private func trackFinished() async {
        guard case .finished(let date) = model.syncStatus else {
            showsFinished = false
            return
        }
        let remaining = SyncStatusPillConstants.finishedSeconds - Date.now.timeIntervalSince(date)
        guard remaining > 0 else {
            showsFinished = false
            return
        }
        showsFinished = true
        try? await Task.sleep(for: .seconds(remaining))
        if !Task.isCancelled { showsFinished = false }
    }
}
