import Insights
import Reports
import SwiftUI
import WorkoutAnalysis

struct TodayOutlookCard: View {
    let model: TodayModel

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
                Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(Array(stride(from: 0, to: predictions.count, by: 2)), id: \.self) { start in
                        GridRow {
                            ForEach(predictions[start..<min(start + 2, predictions.count)], id: \.label) { tile($0) }
                        }
                    }
                }
            }
            if !model.goals.isEmpty {
                divider
                goals
            }
            if model.raceDay != nil {
                divider
                FitnessSection(model: model)
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
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(String(format: C.outlookRaceFormat, model.raceName ?? race.label))
                Spacer()
                (Text("\(days) ").font(BrandFonts.number(22)) + Text(days == 1 ? C.daySingular : C.daysLabel).font(.caption))
                    .foregroundStyle(BrandColors.race)
            }
            Text(TodayText.weeksLeft(days: days)).font(.caption).foregroundStyle(BrandColors.dim)
            GoalBulletChart(today: race.today, raceDay: race.raceDay?.mid, goal: race.goalSeconds, showsGap: true)
        }
    }

    private func tile(_ prediction: Prediction) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(prediction.seconds.map(WorkoutFormat.clock) ?? "—")
                .font(BrandFonts.number(17))
                .foregroundStyle(BrandColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let seconds = prediction.seconds, let meters = prediction.meters, meters > 0 {
                Text(WorkoutListModel.paceText(secondsPerKilometer: seconds / (meters / WorkoutConstants.metersPerKilometer)))
                    .font(BrandFonts.number(13))
                    .foregroundStyle(BrandColors.dim)
                    .lineLimit(1)
            }
            Text(prediction.label).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.goals, id: \.id) { snapshot in
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
