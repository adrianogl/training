import SwiftUI

struct AppUpdateNotice: View {
    let update: AppUpdate
    let openSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        DSNotice(tone: .attention, title: AppUpdateText.title(update), text: AppUpdateText.noticeText(update)) {
            if !update.notes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(update.notes, id: \.self) { note in
                        Text("• \(note)").font(.footnote).foregroundStyle(BrandColors.text)
                    }
                }
            }
            HStack(spacing: DSSpacing.s4) {
                Button(AppUpdateText.openSettings, action: openSettings).foregroundStyle(BrandColors.attention)
                Button(AppUpdateText.dismiss, action: dismiss).foregroundStyle(BrandColors.dim)
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.plain)
        }
    }
}
