import Insights
import SwiftUI

struct TrainerTodayCard: View {
    let trainer: TrainerModel
    let score: Int?
    let factor: TrainerReadinessFactor?

    var body: some View {
        if trainer.plan != nil, let row = trainer.row(for: trainer.currentDay.iso) {
            let suggestion = trainer.readinessSuggestion(score: score, factor: factor)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(TrainerText.todayCardTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Spacer()
                    if let suggestion {
                        Text("prontidão \(suggestion.score)").font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
                    } else if row.run != nil {
                        Text(TrainerText.todayDone).font(.caption).foregroundStyle(BrandColors.accent)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    TrainerDayLineView(line: TrainerText.dayLine(row.workout, strength: row.strength, longStage: row.longStage), titleFont: .footnote)
                }
                if let suggestion {
                    Text(TrainerText.readinessSuggestionText(suggestion)).font(.footnote).foregroundStyle(BrandColors.text)
                    HStack(spacing: 8) {
                        Button(TrainerText.acceptReadiness) { Task { await trainer.acceptReadiness(suggestion) } }
                            .buttonStyle(TrainerPrimaryButtonStyle())
                        Button(TrainerText.keepReadiness) { trainer.keepReadiness(suggestion) }
                            .buttonStyle(TrainerSecondaryButtonStyle())
                    }
                    .disabled(trainer.isWorking)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }
}
