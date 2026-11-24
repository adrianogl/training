import Insights
import Reports
import SwiftUI
import WorkoutAnalysis

struct TodayOutlookCard: View {
    let model: TodayModel

    @Environment(\.openURL) private var openURL
    private typealias C = TodayConstants

    var body: some View {
        let predictions = TodayOutlookText.predictions(model.summary.predictions)
        VStack(alignment: .leading, spacing: 12) {
            if let days = model.summary.raceCountdownDays {
                race(days: days)
            } else {
                DSCardLabel(C.predictionsTitle)
            }
            if !predictions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(predictions, id: \.label) { tile($0) }
                }
            }
            if !otherGoals.isEmpty {
                divider
                goals
            }
            if model.raceDay != nil {
                divider
                FitnessSection(model: model)
            }
            if model.summary.raceCountdownDays != nil, let url = URL(string: C.racesDeepLink) {
                Button { openURL(url) } label: { CardLinkFooter(title: CardLinkConstants.race) }
                    .buttonStyle(.cardLink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var divider: some View {
        Divider().overlay(BrandColors.line).padding(.vertical, C.outlookDividerPadding)
    }

    private func race(days: Int) -> some View {
        let race = model.summary.race
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(String(format: C.outlookRaceFormat, model.raceName ?? race.label))
                Spacer()
                Text(String(format: days == 1 ? C.outlookInOneDay : C.outlookInDaysFormat, days))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BrandColors.race)
            }
            HStack(alignment: .firstTextBaseline) {
                value(C.bulletGoal, race.goalSeconds, BrandColors.accent)
                Spacer()
                value(C.bulletToday, race.today, BrandColors.text)
                Spacer()
                value(C.bulletRaceDay, race.raceDay?.mid, BrandColors.race)
            }
            GoalBulletChart(today: race.today, raceDay: race.raceDay?.mid, goal: race.goalSeconds, showsGap: true, compact: true)
        }
    }

    @ViewBuilder
    private func value(_ label: String, _ seconds: Double?, _ color: Color) -> some View {
        if let seconds {
            (Text(label + " ").font(.caption).foregroundStyle(BrandColors.dim) + Text(WorkoutFormat.clock(seconds)).font(BrandFonts.number(16)).foregroundStyle(color))
        }
    }

    private var otherGoals: [GoalSnapshot] {
        let race = model.summary.race
        return model.goals.filter { snapshot in
            guard let target = snapshot.targetSeconds, let goal = race.goalSeconds else { return true }
            return !(abs(snapshot.distanceKm * WorkoutConstants.metersPerKilometer - race.distance) < C.outlookSameDistanceMeters && abs(target - goal) < 1)
        }
    }

    private func tile(_ prediction: Prediction) -> some View {
        let isRace = model.summary.raceCountdownDays != nil && prediction.meters.map { abs($0 - model.summary.race.distance) < C.outlookSameDistanceMeters } == true
        return VStack(alignment: .leading, spacing: 1) {
            Text(prediction.label).font(.caption2).foregroundStyle(BrandColors.dim)
            Text(prediction.seconds.map(WorkoutFormat.clock) ?? "—")
                .font(BrandFonts.number(15))
                .foregroundStyle(BrandColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let seconds = prediction.seconds, let meters = prediction.meters, meters > 0 {
                Text(WorkoutListModel.paceText(secondsPerKilometer: seconds / (meters / WorkoutConstants.metersPerKilometer)))
                    .font(.caption2)
                    .foregroundStyle(BrandColors.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous).strokeBorder(isRace ? BrandColors.accent : .clear, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(otherGoals, id: \.id) { snapshot in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(GoalsText.title(kind: snapshot.kind, distanceKm: snapshot.distanceKm, targetSeconds: snapshot.targetSeconds))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandColors.text)
                        if let today = TodayOutlookText.goalToday(snapshot) {
                            Text(today).font(.caption).foregroundStyle(BrandColors.dim)
                        }
                    }
                    Spacer()
                    if let status = TodayOutlookText.goalStatus(snapshot) {
                        Text(status.text)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(status.good ? BrandColors.accent : BrandColors.attention)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
