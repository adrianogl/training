import SwiftUI

struct StrengthDayCard: View {
    let model: StrengthDayCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: StrengthPlanUIConstants.spacing) {
            HStack(alignment: .center, spacing: DSSpacing.s2) {
                DSCardLabel(StrengthPlanText.strengthLabel)
                Text(StrengthPlanText.labelSeparator).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.dim)
                if model.isClaude {
                    ClaudeSourceChip()
                } else {
                    TrainerStrengthSourceChip(source: model.source)
                }
                Spacer(minLength: DSSpacing.s2)
                if model.isDone {
                    Text(TrainerConstants.strengthDone).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
                if let minutes = model.minutes {
                    Text(StrengthPlanText.minutes(minutes)).font(.footnote.weight(.medium)).foregroundStyle(BrandColors.dim)
                }
            }
            Text(model.title).font(.headline).foregroundStyle(BrandColors.text)
            if let subtitle = model.subtitle {
                Text(subtitle).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            if let note = model.note {
                Text(note).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
            }
            if model.showsLink {
                CardLinkFooter(title: CardLinkConstants.workout).padding(.top, DSSpacing.s1)
            }
        }
        .brandCard()
    }
}
