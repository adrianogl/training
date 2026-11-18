import Insights
import SwiftUI

struct TrainerChangesView: View {
    @Environment(AppModel.self) private var app
    @State private var selected: Int?

    var body: some View {
        let versions = Array((app.trainer.plan?.versions ?? []).reversed())
        let current = versions.first { $0.number == selected } ?? versions.first
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(TrainerText.changesTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                if let current {
                    TrainerVersionCard(version: current)
                }
                if versions.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        DSCardLabel(TrainerText.versionsTitle)
                        ForEach(versions, id: \.number) { version in
                            Button { selected = version.number } label: {
                                HStack {
                                    Text("v\(version.number) · \(TrainerText.dayMonth(version.createdAt)) · \(TrainerText.triggerText(version.trigger))")
                                        .font(.caption)
                                        .foregroundStyle(version.number == current?.number ? BrandColors.text : BrandColors.dim)
                                    Spacer()
                                    if version.number == versions.first?.number {
                                        Text(TrainerText.currentVersion).font(.caption).foregroundStyle(BrandColors.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .brandCard()
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { app.trainer.markSeen() }
    }
}
