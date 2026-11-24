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
            DSNotice(tone: .error, text: error)
        } else if let notice {
            DSNotice(tone: .success, text: notice)
        }
    }
}
