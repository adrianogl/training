import Insights
import SwiftUI

struct StrengthTodayCard: View {
    let model: StrengthModel

    var body: some View {
        if let workout = model.todayWorkout {
            NavigationLink(value: StrengthRoute.workout(workout.id)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(StrengthText.fromCoach).font(.caption).foregroundStyle(BrandColors.dim)
                        Spacer()
                    }
                    Text(workout.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
                    BodyMapView(levels: model.levels(for: workout), height: StrengthConstants.todayMapHeight)
                    HStack {
                        Text(StrengthText.countLabel(exercises: workout.blocks.flatMap(\.exercises).count, sets: workout.totalSets))
                            .font(.caption).foregroundStyle(BrandColors.dim)
                        Spacer()
                        Text(StrengthText.seeWorkout).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                    }
                }
                .brandCard()
            }
            .buttonStyle(.plain)
        } else {
            Text(model.hasGarminAccount ? StrengthText.noToday : StrengthText.signInHint)
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
                .brandCard()
        }
    }
}

struct StrengthWeekCard: View {
    let model: StrengthModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(model.weekDays) { day in
                    VStack(spacing: 3) {
                        Text(StrengthText.weekday(day.day))
                            .font(.caption2.weight(day.day == .today() ? .bold : .regular))
                            .foregroundStyle(day.day == .today() ? BrandColors.text : BrandColors.dim)
                        chip(day.run, color: day.runKind.map(runColor) ?? BrandColors.accent)
                        chip(day.strength, color: BrandColors.strength)
                        if day.run == nil && day.strength == nil {
                            chip(StrengthText.off, color: BrandColors.dim)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if model.weekWorkouts.isEmpty && model.isLoaded {
                Text(StrengthText.noWeek).font(.caption).foregroundStyle(BrandColors.dim)
            }
            ForEach(model.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Text("!").font(.footnote.weight(.bold)).foregroundStyle(BrandColors.attention)
                    Text(warning).font(.footnote).foregroundStyle(BrandColors.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .brandCard()
    }

    @ViewBuilder
    private func chip(_ text: String?, color: Color) -> some View {
        if let text {
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func runColor(_ kind: TrainerDayKind) -> Color {
        [.threshold, .vo2max].contains(kind) ? BrandColors.attention : kind == .race ? BrandColors.race : BrandColors.accent
    }
}

struct StrengthMusclesCard: View {
    let model: StrengthModel

    var body: some View {
        NavigationLink(value: StrengthRoute.volume) {
            VStack(alignment: .leading, spacing: 8) {
                BodyMapView(levels: model.weekLevels, height: StrengthConstants.weekMapHeight)
                BodyMapLegend()
                HStack {
                    Text(StrengthText.weekLabel(sessions: model.weekWorkouts.count, sets: model.weekSetCount))
                        .font(.caption).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(StrengthText.seeVolume).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
            }
            .brandCard()
        }
        .buttonStyle(.plain)
    }
}

struct StrengthHistoryCard: View {
    let model: StrengthModel

    var body: some View {
        NavigationLink(value: StrengthRoute.history) {
            VStack(alignment: .leading, spacing: 8) {
                StrengthFrequencyBars(counts: model.weeklyCounts)
                HStack {
                    Text("\(StrengthText.average) \(StrengthText.averageLabel(model.averagePerWeek)) por semana")
                        .font(.caption).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(StrengthText.seeSessions).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
            }
            .brandCard()
        }
        .buttonStyle(.plain)
    }
}

struct StrengthFrequencyBars: View {
    let counts: [Int]

    var body: some View {
        let top = max(counts.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                RoundedRectangle(cornerRadius: 2)
                    .fill(BrandColors.accentFill.opacity(index == counts.count - 1 ? 1 : 0.5))
                    .frame(height: max(2, StrengthConstants.freqHeight * CGFloat(count) / CGFloat(top)))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: StrengthConstants.freqHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }
}
