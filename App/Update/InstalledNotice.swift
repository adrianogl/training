import SwiftUI

struct InstalledNotice: View {
    let card: InstalledCard
    let dismiss: () -> Void

    var body: some View {
        DSNotice(tone: .success, title: InstallNoticeText.cardTitle(card), text: nil) {
            if !card.notes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(card.notes, id: \.self) { note in
                        Text("• \(note)").font(.footnote).foregroundStyle(BrandColors.text)
                    }
                }
            }
            Button(InstallNoticeText.dismiss, action: dismiss)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BrandColors.accent)
                .buttonStyle(.plain)
        }
    }
}
