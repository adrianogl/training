import SwiftUI

struct AccountPrimaryButton: View {
    let title: String
    var isWorking = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isWorking ? 0 : 1)
                if isWorking { BrandLoader(size: .mini) }
            }
        }
        .buttonStyle(.ds(.primary))
        .disabled(disabled || isWorking)
    }
}

struct AccountMessage: View {
    let error: String?
    let notice: String?

    var body: some View {
        if let error {
            Text(error).font(.footnote).foregroundStyle(BrandColors.danger)
        } else if let notice {
            Text(notice).font(.footnote).foregroundStyle(BrandColors.accent)
        }
    }
}
