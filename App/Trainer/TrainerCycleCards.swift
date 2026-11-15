import Insights
import SwiftUI

struct TrainerCycleSuggestionCard: View {
    let review: TrainerCycleReview
    let dated: Bool
    let ended: Bool
    let onSuggestion: () -> Void
    let onOther: () -> Void

    var body: some View {
        let color = TrainerCycleConstants.color(for: review.verdict)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: TrainerCycleConstants.symbol(for: review.verdict))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                    .frame(width: TrainerCycleConstants.iconSize, height: TrainerCycleConstants.iconSize)
                    .background(
                        color.opacity(TrainerCycleConstants.iconFillOpacity),
                        in: RoundedRectangle(cornerRadius: TrainerCycleConstants.iconRadius, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(TrainerCycleText.verdictTitle(review.verdict)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Text(TrainerCycleText.volumes(review, dated: dated)).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            if !review.reasons.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(review.reasons.prefix(TrainerCycleConstants.maximumReasons).enumerated()), id: \.offset) { _, reason in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").foregroundStyle(BrandColors.dim)
                            Text(TrainerCycleText.reason(reason)).foregroundStyle(BrandColors.text)
                        }
                        .font(.footnote)
                    }
                }
            }
            Button(ended ? TrainerCycleText.createWithSuggestion : TrainerCycleText.applySuggestion, action: onSuggestion)
                .buttonStyle(TrainerPrimaryButtonStyle())
            Button(TrainerCycleText.chooseOther, action: onOther)
                .buttonStyle(TrainerSecondaryButtonStyle())
        }
        .brandCard()
    }
}

struct TrainerCycleRaceCard: View {
    let seconds: Double
    let goal: Double?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(TrainerCycleText.clock(seconds)).font(BrandFonts.number(18)).foregroundStyle(BrandColors.text)
            if let goal {
                Text(TrainerCycleText.goal(goal)).font(.footnote).foregroundStyle(BrandColors.dim)
                Spacer(minLength: 6)
                Text(TrainerCycleText.raceDifference(seconds: seconds, goal: goal))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(seconds <= goal ? BrandColors.accent : BrandColors.attention)
            }
        }
        .brandCard()
    }
}

struct TrainerCycleVolumeCard: View {
    let review: TrainerCycleReview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(TrainerCycleText.volumeDone(review)).font(BrandFonts.number(18)).foregroundStyle(BrandColors.text)
                Text(TrainerCycleText.volumeShare(review)).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            TrainerCycleChart(weeks: review.weeks)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(TrainerCycleText.chartLabel(review))
            HStack(spacing: 12) {
                legend(BrandColors.accentFill, TrainerCycleText.chartDone)
                legend(BrandColors.track, TrainerCycleText.chartPlanned)
                legend(BrandColors.attention, TrainerCycleText.chartBelow)
            }
        }
        .brandCard()
    }

    private func legend(_ color: Color, _ name: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(color).frame(width: TrainerCycleConstants.legendWidth, height: TrainerCycleConstants.legendHeight)
            Text(name).font(.caption2).foregroundStyle(BrandColors.dim)
        }
    }
}

struct TrainerCycleChart: View {
    let weeks: [TrainerCycleWeek]

    var body: some View {
        let height = TrainerCycleConstants.chartHeight
        let top = max(weeks.map(\.plannedMeters).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: TrainerCycleConstants.barSpacing) {
            ForEach(weeks, id: \.index) { week in
                let shape = RoundedRectangle(cornerRadius: TrainerCycleConstants.barRadius)
                ZStack(alignment: .bottom) {
                    shape.fill(BrandColors.track).frame(height: height * week.plannedMeters / top)
                    shape
                        .fill(TrainerCycleConstants.shareColor(done: week.doneMeters, total: week.plannedMeters))
                        .frame(height: height * min(week.doneMeters / top, 1))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

struct TrainerCycleKeyCard: View {
    let review: TrainerCycleReview

    private var rows: [(String, TrainerCycleCount)] {
        [
            (TrainerCycleText.keyLong, review.long),
            (TrainerCycleText.keyThreshold, review.threshold),
            (TrainerCycleText.keyVo2, review.vo2),
            (TrainerCycleText.keyMediumLong, review.mediumLong),
        ]
        .filter { $0.1.total > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rows, id: \.0) { title, count in
                row(title, count)
            }
            if let longest = review.longestLongMeters {
                Text(TrainerCycleText.longest(longest)).font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
        .brandCard()
    }

    private func row(_ title: String, _ count: TrainerCycleCount) -> some View {
        let below = TrainerCycleConstants.isBelow(done: Double(count.done), total: Double(count.total))
        let share = count.total == 0 ? 0 : min(Double(count.done) / Double(count.total), 1)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.footnote).foregroundStyle(BrandColors.text)
                Spacer(minLength: 6)
                Text(TrainerCycleText.count(count))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(below ? BrandColors.attention : BrandColors.dim)
            }
            Capsule()
                .fill(BrandColors.track)
                .frame(height: TrainerCycleConstants.progressHeight)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule().fill(below ? BrandColors.attention : BrandColors.accentFill).frame(width: proxy.size.width * share)
                    }
                }
        }
    }
}

struct TrainerCycleBodyCard: View {
    let review: TrainerCycleReview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let first = review.readinessFirst, let last = review.readinessLast {
                row(TrainerCycleText.readinessTitle, TrainerCycleText.readinessCaption(first), TrainerCycleText.readiness(last))
                Divider()
                row(
                    TrainerCycleText.lowReadinessTitle,
                    TrainerCycleText.lowReadinessCaption(TrainerEngine.cycleLowReadiness),
                    String(review.lowReadinessDays)
                )
            } else {
                Text(TrainerCycleText.noReadiness).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            Divider()
            row(TrainerCycleText.lightWeeksTitle, TrainerCycleText.lightWeeksCaption, String(review.extraLightWeeks.count))
            Divider()
            row(TrainerCycleText.longsMissedTitle, TrainerCycleText.longsMissedCaption(review.long.total), String(review.longsMissed))
        }
        .brandCard()
    }

    private func row(_ title: String, _ caption: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).foregroundStyle(BrandColors.text)
                Text(caption).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 6)
            Text(value).font(BrandFonts.number(18)).foregroundStyle(BrandColors.text)
        }
    }
}

struct TrainerCycleFormCard: View {
    let predictions: [TrainerCycleChange]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(predictions.enumerated()), id: \.offset) { offset, change in
                if offset > 0 { Divider() }
                row(change)
            }
        }
        .brandCard()
    }

    private func row(_ change: TrainerCycleChange) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(TrainerCycleText.predictionTitle(change.meters)).font(.subheadline).foregroundStyle(BrandColors.text)
                Text(TrainerCycleText.predictionCaption(change)).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(TrainerCycleText.clock(change.last)).font(BrandFonts.number(18)).foregroundStyle(BrandColors.text)
                Text(TrainerCycleText.predictionDelta(change))
                    .font(.caption)
                    .foregroundStyle(deltaColor(change))
            }
        }
    }

    private func deltaColor(_ change: TrainerCycleChange) -> Color {
        let delta = (change.last - change.first).rounded()
        if delta < 0 { return BrandColors.accent }
        if delta > 0 { return BrandColors.attention }
        return BrandColors.dim
    }
}
