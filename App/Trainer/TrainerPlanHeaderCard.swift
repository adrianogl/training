import Insights
import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct TrainerPlanHeaderCard: View {
    let plan: TrainerPlan
    let boards: [TrainerScoreboard]
    let cells: [TrainerWeekCell]
    let weeksToTarget: Int?
    let weekProgress: String?
    let onToggleLight: (Day) -> Void
    let onSelect: (Day) -> Void
    var cycle: TrainerCycleReview?
    @State private var showsPastBoards = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainerPlanGoalRow(plan: plan, weeksToTarget: weeksToTarget, weekProgress: weekProgress)
            if let cycle {
                Divider()
                result(cycle)
            } else if let latest = boards.first {
                Divider()
                scoreboard(latest)
            }
            Divider()
            TrainerWeekStrip(cells: cells, onToggleLight: onToggleLight, onSelect: onSelect)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func result(_ review: TrainerCycleReview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TrainerCycleText.resultTitle)
                .font(.caption.weight(.medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(BrandColors.dim)
            if let value = TrainerCycleText.resultValue(review, goalMeters: plan.target.distanceMeters) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(value).font(BrandFonts.number(18)).foregroundStyle(BrandColors.text)
                    if let caption = TrainerCycleText.resultCaption(review, goalMeters: plan.target.distanceMeters) {
                        Text(caption).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                }
            }
            Text(TrainerCycleText.suggestionLine(review, dated: plan.target.date != nil))
                .font(.footnote)
                .foregroundStyle(TrainerCycleConstants.color(for: review.verdict))
        }
    }

    private func scoreboard(_ latest: TrainerScoreboard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TrainerText.scoreboardTitle(latest.weekIndex))
                .font(.caption.weight(.medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(BrandColors.dim)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(TrainerText.scoreboardKilometers(latest)).font(BrandFonts.number(18)).foregroundStyle(BrandColors.text)
                if let quality = TrainerText.scoreboardQuality(latest) {
                    Text(quality).font(.footnote).foregroundStyle(BrandColors.dim)
                }
                if let prediction = TrainerText.scoreboardPrediction(latest) {
                    Text(prediction).font(.footnote).foregroundStyle(BrandColors.dim)
                }
            }
            if let long = TrainerText.scoreboardLong(latest) {
                Text(long).font(.footnote).foregroundStyle(latest.longClosed == true ? BrandColors.accent : BrandColors.attention)
            }
            if boards.count > 1 {
                Button { showsPastBoards.toggle() } label: {
                    HStack(spacing: 6) {
                        Text(TrainerText.pastScoreboards).font(.caption.weight(.medium))
                        Spacer()
                        CardDisclosure(expanded: showsPastBoards)
                    }
                    .foregroundStyle(BrandColors.dim)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showsPastBoards {
                    ForEach(boards) { board in
                        Text(TrainerText.scoreboardRow(board)).font(.caption).foregroundStyle(BrandColors.dim).monospacedDigit()
                    }
                }
            }
        }
    }
}

struct TrainerPlanGoalRow: View {
    let plan: TrainerPlan
    var weeksToTarget: Int?
    var weekProgress: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(TrainerText.goalLabel)
                Spacer(minLength: 6)
                if let weekProgress {
                    Text(weekProgress).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            Text(TrainerText.targetTitle(plan.target)).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            Text(TrainerText.goalCaption(plan: plan, weeks: weeksToTarget)).font(.caption).foregroundStyle(BrandColors.dim)
            if let needed = TrainerEngine.requiredThreshold(target: plan.target) {
                HStack(alignment: .top, spacing: 12) {
                    DSStat(value: WorkoutFormat.clock(plan.paces.threshold), label: TrainerText.thresholdNowLabel)
                    DSStat(value: "~" + WorkoutFormat.clock(needed), label: TrainerText.thresholdNeededLabel)
                }
                .padding(.top, 4)
                Text(TrainerText.thresholdGap(current: plan.paces.threshold, needed: needed))
                    .font(.footnote)
                    .foregroundStyle(plan.paces.threshold > needed ? BrandColors.attention : BrandColors.accent)
            }
        }
    }
}
