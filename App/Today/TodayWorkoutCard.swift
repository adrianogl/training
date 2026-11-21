import GarminAPI
import Insights
import SwiftUI
import TrainingCore

struct TodayWorkoutCard: View {
    let model: TodayModel
    let trainer: TrainerModel
    let pick: TodayWorkoutPick
    var legDay: StrengthLegDay?

    @State private var weather: [HourlyWeather] = []
    @State private var todayWeather: [HourlyWeather]?
    private typealias C = TodayConstants

    var body: some View {
        let score = model.summary.readinessFromYesterday ? nil : model.summary.readiness?.score ?? model.fallbackScore
        let suggestion = trainer.readinessSuggestion(score: score, factor: TrainerModel.lowestFactor(model.summary.readiness))
        let display = todayPlan.map { adjustDisplay($0, score: score, showsAdvice: suggestion == nil) }
        VStack(alignment: .leading, spacing: 12) {
            header(display)
            switch pick.today {
            case .garmin(let plan): garmin(plan, display: display ?? DayAdjustText.display(.none, plan: plan, hour: usualHour))
            case .trainer(let row): TrainerDayLineView(line: TrainerText.dayLine(row.workout, strength: row.strength, longStage: row.longStage, estimate: row.estimate), titleFont: .title3)
            case nil: rest
            }
            if let suggestion { readiness(suggestion) }
            if let advice = StrengthLegAdvice.text(pick.today, leg: legDay) {
                DSNotice(tone: .attention, text: advice)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .task(id: pick.tomorrow == nil ? nil : model.today.iso) {
            guard pick.tomorrow != nil else { return }
            weather = await trainer.forecast(for: model.today.adding(days: 1))
        }
        .task(id: todayPlan?.id) {
            guard todayPlan != nil else { return }
            todayWeather = await trainer.forecast(for: model.today)
        }
    }

    private var todayPlan: PlannedWorkout? {
        guard case .garmin(let plan) = pick.today else { return nil }
        return plan
    }

    private var usualHour: Int {
        DayAdjust.usualHour(model.recentRunStarts, calendar: .current)
    }

    private func adjustDisplay(_ plan: PlannedWorkout, score: Int?, showsAdvice: Bool) -> DayAdjustDisplay {
        guard showsAdvice, let forecast = todayWeather else { return DayAdjustText.display(.none, plan: plan, hour: usualHour) }
        let input = DayAdjustText.input(
            plan: plan, score: score, forecast: forecast, hour: usualHour, hotSessions: model.hotSessions, heavyLegs: legDay != nil
        )
        return DayAdjustText.display(DayAdjust.adjust(input), plan: plan, hour: usualHour)
    }

    private func header(_ display: DayAdjustDisplay?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            DSCardLabel(title)
            Spacer()
            switch pick.today {
            case .garmin(let plan):
                if let estimate = PlanText.estimate(PlanText.adjusted(plan, steps: display?.steps ?? plan.steps), fallback: trainer.easyPaceBand) {
                    Text(estimate).font(.caption).foregroundStyle(BrandColors.dim)
                }
            case .trainer(let row):
                if row.run != nil {
                    Text(TrainerText.todayDone).font(.caption).foregroundStyle(BrandColors.accent)
                }
            case nil:
                if pick.tomorrow != nil {
                    Text(C.workoutTomorrow).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
        }
    }

    private var title: String {
        switch pick.today ?? pick.tomorrow {
        case .garmin: String(format: C.workoutTitleFormat, C.planTitle, C.workoutSourceGarmin)
        case .trainer: String(format: C.workoutTitleFormat, C.planTitle, C.workoutSourceTrainer)
        case nil: !trainer.hasActivePlan ? C.planTitle : String(format: C.workoutTitleFormat, C.planTitle, C.workoutSourceTrainer)
        }
    }

    private func garmin(_ plan: PlannedWorkout, display: DayAdjustDisplay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TodayGarminPlanContent(plan: plan, display: display)
            NavigationLink(value: TodayRoute.planned(plan.id)) { CardLinkFooter(title: CardLinkConstants.workout) }
                .buttonStyle(.cardLink)
        }
    }

    private var rest: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.weekRuns[model.today]?.isEmpty == false ? C.runDoneTitle : TrainerText.restTitle).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            switch pick.tomorrow {
            case .garmin(let plan):
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(C.workoutTomorrowPrefix): \(plan.title)").font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.text)
                    if let estimate = PlanText.estimate(plan, fallback: trainer.easyPaceBand) {
                        Text(estimate).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                }
            case .trainer(let row):
                let line = TrainerText.dayLine(row.workout, strength: row.strength, longStage: row.longStage, estimate: row.estimate)
                VStack(alignment: .leading, spacing: 2) {
                    TrainerDayLineView(line: TrainerDayLine(title: "\(C.workoutTomorrowPrefix): \(line.title)", detail: line.detail, tags: line.tags), titleFont: .footnote)
                }
            case nil:
                Text(C.workoutNothingTomorrow).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            if pick.tomorrow != nil, let best = TrainerBestTimeBuilder.make(weather: weather, longPace: trainer.plan?.paces.long) {
                bestTime(best)
            }
        }
    }

    private func bestTime(_ best: TrainerBestTime) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(C.workoutBestTimeTitle).font(.caption).foregroundStyle(BrandColors.dim)
                Spacer()
                Text("\(TrainerText.bestTimeStart(best.hour)) · \(TrainerText.temperature(best.temperature))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(best.heat.isHot ? BrandColors.attention : BrandColors.accent)
                    .monospacedDigit()
            }
            if best.heat.isHot {
                Text(TrainerText.heatWarning(best.heat, hasBlocks: hasBlocks)).font(.caption).foregroundStyle(BrandColors.dim)
            } else if let later = best.laterHotHour {
                Text(TrainerText.heatLater(hour: later, hasBlocks: hasBlocks, blockReduction: best.laterBlockReduction)).font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
        .padding(10)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var hasBlocks: Bool {
        guard case .trainer(let row) = pick.tomorrow else { return false }
        return TrainerEngine.plannedPauses(of: row.workout) > 0
    }

    private func readiness(_ suggestion: TrainerReadinessSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(BrandColors.line)
            Text(String(format: C.workoutReadinessFormat, suggestion.score)).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
            Text(TrainerText.readinessSuggestionText(suggestion)).font(.footnote).foregroundStyle(BrandColors.text)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(TrainerText.acceptReadiness) { Task { await trainer.acceptReadiness(suggestion) } }
                    .buttonStyle(.ds(.primary))
                Button(TrainerText.keepReadiness) { trainer.keepReadiness(suggestion) }
                    .buttonStyle(.ds(.secondary))
            }
            .disabled(trainer.isWorking)
        }
    }
}
