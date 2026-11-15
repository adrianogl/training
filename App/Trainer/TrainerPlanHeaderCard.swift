import Insights
import SwiftUI
import TrainingCore

struct TrainerPlanHeaderCard: View {
    let plan: TrainerPlan
    let boards: [TrainerScoreboard]
    let cells: [TrainerWeekCell]
    let weeksToTarget: Int?
    let weekProgress: String?
    let onToggleLight: (Day) -> Void
    let onSelect: (Day) -> Void
    @State private var showsPastBoards = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            goal
            if let latest = boards.first {
                Divider()
                scoreboard(latest)
            }
            Divider()
            TrainerWeekStrip(cells: cells, onToggleLight: onToggleLight, onSelect: onSelect)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var goal: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(TrainerText.goalGlyph(plan.target))
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(BrandColors.race)
                .frame(width: TrainerConstants.goalIconSize, height: TrainerConstants.goalIconSize)
                .background(BrandColors.raceGlow, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(TrainerText.targetTitle(plan.target)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(TrainerText.goalCaption(plan: plan, weeks: weeksToTarget)).font(.caption).foregroundStyle(BrandColors.dim)
                if let line = TrainerEngine.goalPaceSummary(target: plan.target, paces: plan.paces) {
                    Text(line).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            Spacer(minLength: 6)
            if let weekProgress {
                Text(weekProgress).font(.caption).foregroundStyle(BrandColors.dim)
            }
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
                        Image(systemName: showsPastBoards ? "chevron.down" : "chevron.right").font(.caption2)
                        Text(TrainerText.pastScoreboards).font(.caption.weight(.medium))
                        Spacer()
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
