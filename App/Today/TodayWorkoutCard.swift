import GarminAPI
import Insights
import SwiftUI
import TrainingCore

struct TodayWorkoutCard: View {
    let model: TodayModel
    let trainer: TrainerModel
    let pick: TodayWorkoutPick
    var legDay: StrengthLegDay?

    @Environment(AppModel.self) private var app
    @State private var weather: [HourlyWeather] = []
    @State private var todayWeather: [HourlyWeather]?
    @State private var isSendingNow = false
    @State private var sendNowError: String?
    private typealias C = TodayConstants

    var body: some View {
        let score = model.summary.readinessFromYesterday ? nil : model.summary.readiness?.score ?? model.fallbackScore
        let suggestion = trainer.readinessSuggestion(score: score, factor: TrainerModel.lowestFactor(model.summary.readiness))
        let watch = todayPlan.flatMap { trainer.watchDayAdjust(planId: $0.id) }
        let display = todayPlan.map { plan in
            watch.map { DayAdjustText.watchDisplay($0, plan: plan) } ?? adjustDisplay(plan, score: score, showsAdvice: suggestion == nil)
        }
        VStack(alignment: .leading, spacing: 12) {
            header(display)
            switch pick.today {
            case .garmin(let plan):
                garmin(plan, display: display ?? DayAdjustText.display(.none, plan: plan, hour: usualHour), watch: watch, score: score)
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
        DayAdjustText.usualHour(for: todayPlan, runs: model.recentRuns)
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

    private func garmin(_ plan: PlannedWorkout, display: DayAdjustDisplay, watch: DayAdjustWatch?, score: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TodayGarminPlanContent(plan: plan, display: display)
            if let watch {
                watchStatus(watch, score: score)
            }
            NavigationLink(value: TodayRoute.planned(plan.id)) { CardLinkFooter(title: CardLinkConstants.workout) }
                .buttonStyle(.cardLink)
        }
    }

    @ViewBuilder
    private func watchStatus(_ watch: DayAdjustWatch, score: Int?) -> some View {
        if let status = DayAdjustWatchRules.status(watch) {
            Text(status).font(.caption).foregroundStyle(BrandColors.dim).monospacedDigit()
        }
        if let now = nowEntries(watch, score: score), DayAdjustWatchRules.showsNow(watch, now: now) {
            Button {
                sendNow(now)
            } label: {
                HStack(spacing: 8) {
                    if isSendingNow { ProgressView().controlSize(.small) }
                    Text(isSendingNow ? DayAdjustWatchConstants.sendingNow : String(format: DayAdjustWatchConstants.nowButtonFormat, now.hour))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ds(.secondary))
            .disabled(isSendingNow || trainer.isSendingToGarmin)
        }
        if let sendNowError {
            DSNotice(tone: .attention, text: sendNowError)
        }
    }

    private func nowEntries(_ watch: DayAdjustWatch, score: Int?) -> DayAdjustEntries? {
        guard let forecast = todayWeather, !forecast.isEmpty else { return nil }
        let now = Date.now
        return DayAdjustWatchRules.candidate(
            day: watch.entries.day, score: score, forecast: forecast, hour: Calendar.current.component(.hour, from: now),
            origin: .now, hotSessions: model.hotSessions, heavyLegs: legDay != nil, now: now
        )
    }

    private func sendNow(_ entries: DayAdjustEntries) {
        isSendingNow = true
        sendNowError = nil
        Task {
            let result = await trainer.sendNowDayAdjust(entries, client: app.garminAccount.client)
            isSendingNow = false
            sendNowError = result?.firstError
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
            if pick.tomorrow != nil, let day = TrainerHeatDayBuilder.make(
                weather: weather, longPace: trainer.plan?.paces.long, usualHour: tomorrowHour, hotSessions: model.hotSessions
            ), let usual = day.hour(day.usualHour) {
                tomorrowHeat(day, usual: usual)
            }
        }
    }

    private func tomorrowHeat(_ day: TrainerHeatDay, usual: TrainerHeatHour) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(C.workoutBestTimeTitle).font(.caption).foregroundStyle(BrandColors.dim)
                Spacer()
                Text("\(TrainerText.heatHourLabel(usual.hour, usual: true)) · \(TrainerText.temperature(usual.temperature))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(usual.heat.isHot ? BrandColors.attention : BrandColors.accent)
                    .monospacedDigit()
            }
            Text(TrainerText.heatEffect(usual, day: day, hasBlocks: hasBlocks)).font(.caption).foregroundStyle(BrandColors.dim)
            if let better = day.suggestedHour.flatMap(day.hour) {
                Text(TrainerText.heatSwapGainShort(better.hour, seconds: usual.heat.paceOffset - better.heat.paceOffset))
                    .font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
            }
        }
        .padding(10)
        .background(BrandColors.track, in: .dsInner)
    }

    private var tomorrowHour: Int {
        let tomorrow = model.today.adding(days: 1)
        let date = Calendar.current.date(from: DateComponents(year: tomorrow.year, month: tomorrow.month, day: tomorrow.day, hour: 12)) ?? .now
        return UsualHour.hour(for: date, long: tomorrowIsLong, runs: model.recentRuns, now: .now, calendar: .current)
    }

    private var tomorrowIsLong: Bool {
        switch pick.tomorrow {
        case .trainer(let row): row.workout.kind == .long
        case .garmin(let plan): PlanText.shape(plan) == .long
        case nil: false
        }
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
