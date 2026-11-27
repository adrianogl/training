import SwiftUI

struct TrainerPlannedDoneCard: View {
    let row: TrainerDayRow
    let done: [WorkoutRowData]
    let newIds: Set<Int64>

    var body: some View {
        let perfect = done.first { ($0.score ?? 0) >= ScoreConstants.perfectScore }
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: TrainerRoute.day(row.id)) { planned }
                .buttonStyle(.cardLink)
            ForEach(done) { item in
                Divider().overlay(BrandColors.line).padding(.leading, TrainerConstants.dayDateWidth + 10)
                NavigationLink(value: TrainerRoute.workout(item.activityId)) {
                    VStack(alignment: .leading, spacing: 6) {
                        doneLabel
                        WorkoutRow(row: item, isFromPlan: true, isNew: newIds.contains(item.activityId), isEmbedded: true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .brandCard()
        .perfectScoreCard(score: perfect?.score, activityId: perfect?.activityId ?? 0)
        .recordCard(perfect == nil && done.contains { $0.recordPill != nil })
    }

    private var planned: some View {
        let workout = row.workout
        return VStack(alignment: .leading, spacing: 6) {
            DSCardLabel(TrainerText.plannedLabel)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(TrainerText.weekdayShort(workout.day))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                    Text("\(workout.day.day)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                }
                .frame(width: TrainerConstants.dayDateWidth, alignment: .leading)
                RoundedRectangle(cornerRadius: 3)
                    .fill(TrainerConstants.color(for: workout.kind))
                    .frame(width: TrainerConstants.dayBarWidth)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 2) {
                    TrainerDayLineView(line: TrainerText.dayLine(workout, longStage: row.longStage, estimate: row.estimate), titleFont: .subheadline)
                }
                Spacer(minLength: 6)
                CardLinkBadge()
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(Rectangle())
    }

    private var doneLabel: some View {
        Text(TrainerText.doneLabel)
            .font(.caption.weight(.semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(BrandColors.accent)
            .accessibilityAddTraits(.isHeader)
    }
}
