import SwiftUI

struct DSEmptyState: View {
    let symbol: String
    let title: String
    let text: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        DSStateLayout(title: title, text: text) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(BrandColors.dim)
                .frame(width: DSStateConstants.iconSize, height: DSStateConstants.iconSize)
                .background(BrandColors.track, in: Circle())
        } action: {
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.ds(.primary)).fixedSize()
            }
        }
    }
}

struct DSLoadingState: View {
    let title: String
    var text: String?

    var body: some View {
        DSStateLayout(title: title, text: text) {
            BrandLoader(size: .mini)
        } action: {
            EmptyView()
        }
    }
}

struct DSErrorState: View {
    let title: String
    let text: String
    var retryTitle: String = DSStateConstants.retry
    var retry: (() -> Void)?

    var body: some View {
        DSStateLayout(title: title, text: text) {
            Image(systemName: "exclamationmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandColors.danger)
                .frame(width: DSStateConstants.iconSize, height: DSStateConstants.iconSize)
                .background(BrandColors.danger.opacity(0.12), in: Circle())
        } action: {
            if let retry {
                Button(retryTitle, action: retry).buttonStyle(.ds(.secondary)).fixedSize()
            }
        }
    }
}

private struct DSStateLayout<Icon: View, Action: View>: View {
    let title: String
    let text: String?
    @ViewBuilder var icon: Icon
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: DSSpacing.s2) {
            icon
            Text(title).font(.headline).foregroundStyle(BrandColors.text).multilineTextAlignment(.center)
            if let text {
                Text(text).font(.subheadline).foregroundStyle(BrandColors.dim).multilineTextAlignment(.center)
                    .frame(maxWidth: DSStateConstants.textWidth)
            }
            action.padding(.top, DSSpacing.s1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.s6 - 2)
        .padding(.horizontal, DSSpacing.s4)
    }
}
