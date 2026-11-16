import Insights
import SwiftUI
import TrainingCore

struct StrengthCardHeader: View {
    let title: String
    var link: String?

    var body: some View {
        HStack {
            Text(title).font(.caption.weight(.semibold)).tracking(1).textCase(.uppercase).foregroundStyle(BrandColors.dim)
            Spacer()
            if let link {
                Text(link).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
            }
        }
    }
}

struct StrengthTodayWideCard: View {
    let model: StrengthModel

    private typealias C = StrengthConstants

    var body: some View {
        if let workout = model.todayWorkout {
            NavigationLink(value: StrengthRoute.workout(workout.id)) {
                VStack(alignment: .leading, spacing: 12) {
                    StrengthCardHeader(title: StrengthText.today, link: StrengthText.seeWorkout)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
                        Text(StrengthText.todaySubtitle(exercises: workout.blocks.flatMap(\.exercises).count, sets: workout.totalSets))
                            .font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    HStack(alignment: .top, spacing: 16) {
                        BodyMapView(levels: model.levels(for: workout), height: C.wideMapHeight)
                            .frame(width: C.wideMapColumn)
                        StrengthBlockRows(blocks: workout.blocks, showsFirstDivider: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .brandCard()
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                StrengthCardHeader(title: StrengthText.today)
                Text(model.hasMFIT ? StrengthText.noToday : StrengthText.signInHint)
                    .font(.footnote).foregroundStyle(BrandColors.dim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }
}

struct StrengthWeekListCard: View {
    let model: StrengthModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StrengthCardHeader(title: StrengthText.week)
            VStack(spacing: 0) {
                ForEach(Array(model.weekDays.enumerated()), id: \.element.id) { index, day in
                    row(day)
                        .overlay(alignment: .top) { if index > 0 { Divider().overlay(BrandColors.line) } }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func row(_ day: StrengthDay) -> some View {
        let isToday = day.day == Day.today()
        return HStack(spacing: 10) {
            Text(StrengthText.weekday(day.day))
                .font(.caption.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? BrandColors.text : BrandColors.dim)
                .frame(width: 34, alignment: .leading)
            StrengthDayChips(day: day)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

private struct StrengthDayChips: View {
    let day: StrengthDay

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 4) { chips }
        }
    }

    @ViewBuilder
    private var chips: some View {
        if let kind = day.runKind {
            StrengthChip(text: StrengthText.runKindName(kind), detail: day.runKilometers, color: color(kind))
        }
        if let strength = day.strength {
            StrengthChip(text: StrengthText.strengthChip(strength), color: BrandColors.strength)
        }
        if day.runKind == nil && day.strength == nil {
            StrengthChip(text: StrengthText.rest, color: BrandColors.dim)
        }
    }

    private func color(_ kind: TrainerDayKind) -> Color {
        [.threshold, .vo2max].contains(kind) ? BrandColors.attention : kind == .race ? BrandColors.race : BrandColors.accent
    }
}

struct StrengthMusclesWideCard: View {
    let model: StrengthModel

    private typealias C = StrengthConstants

    var body: some View {
        NavigationLink(value: StrengthRoute.volume) {
            VStack(alignment: .leading, spacing: 12) {
                StrengthCardHeader(title: StrengthText.weekMuscles, link: StrengthText.seeVolume)
                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 8) {
                        BodyMapView(levels: model.weekLevels, height: C.wideWeekMapHeight)
                        legend
                    }
                    .frame(width: C.wideMapColumn)
                    groups
                }
                Text(StrengthText.weekLabel(sessions: model.weekWorkouts.count, sets: model.weekSetCount))
                    .font(.caption).foregroundStyle(BrandColors.dim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(Array(StrengthText.legendShort.enumerated()), id: \.offset) { index, text in
                HStack(spacing: 4) {
                    Circle().fill(C.heat[index]).frame(width: 7, height: 7)
                    Text(text)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(BrandColors.dim)
    }

    private var groups: some View {
        let totals = model.weekGroupTotals
        let top = max(totals.first?.sets ?? 1, 1)
        return VStack(spacing: 8) {
            ForEach(totals) { total in
                HStack(spacing: 10) {
                    Text(StrengthText.groupName(total.group)).font(.footnote).foregroundStyle(BrandColors.text)
                        .frame(width: 92, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(C.heat[max(min(total.level, C.heat.count), 1) - 1])
                            .frame(width: max(6, proxy.size.width * total.sets / top), height: 8)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 12)
                    Text("\(Int(total.sets.rounded()))").font(BrandFonts.number(14)).foregroundStyle(BrandColors.text)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct StrengthHistoryWideCard: View {
    let model: StrengthModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: StrengthRoute.history) {
                VStack(alignment: .leading, spacing: 12) {
                    StrengthCardHeader(title: StrengthText.history, link: StrengthText.seeSessions)
                    HStack(spacing: 22) {
                        stat(StrengthText.averageLabel(model.averagePerWeek), StrengthText.perWeekShort)
                        stat("\(model.thisWeekSessions)", StrengthText.thisWeek)
                    }
                    StrengthFrequencyBars(counts: model.weeklyCounts)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            VStack(spacing: 0) {
                ForEach(model.recentSessions) { session in
                    NavigationLink(value: StrengthRoute.session(session.id)) {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(StrengthText.shortTitle(session.title)).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.text)
                                Text(StrengthText.sessionLine(session)).font(.caption).foregroundStyle(BrandColors.dim)
                            }
                            Spacer(minLength: 8)
                            Text(StrengthText.sessionStats(session)).font(BrandFonts.number(13)).foregroundStyle(BrandColors.dim)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { Divider().overlay(BrandColors.line) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
            Text(label).font(.caption2).foregroundStyle(BrandColors.dim)
        }
    }
}
