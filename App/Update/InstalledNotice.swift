import SwiftUI

struct InstalledNotice: View {
    let card: InstalledCard
    let dismiss: () -> Void

    var body: some View {
        DSNotice(tone: .success, title: InstallNoticeText.cardTitle(card), text: nil) {
            if !card.notes.isEmpty {
                DSBulletList(items: card.notes)
            }
            Button(InstallNoticeText.dismiss, action: dismiss)
                .buttonStyle(.ds(.text))
        }
    }
}
