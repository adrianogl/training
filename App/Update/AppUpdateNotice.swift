import SwiftUI

struct AppUpdateNotice: View {
    let update: AppUpdate
    let openSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        DSNotice(tone: .attention, title: AppUpdateText.title(update), text: AppUpdateText.noticeText(update)) {
            if !update.notes.isEmpty {
                DSBulletList(items: update.notes)
            }
            HStack(spacing: DSSpacing.s4) {
                Button(AppUpdateText.openSettings, action: openSettings)
                Button(AppUpdateText.dismiss, action: dismiss)
            }
            .buttonStyle(.ds(.text))
        }
    }
}
