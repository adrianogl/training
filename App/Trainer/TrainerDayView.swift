import Insights
import Storage
import SwiftUI
import TrainingCore

struct TrainerDayView: View {
    @Environment(AppModel.self) private var app
    let iso: String
    @State private var weather: [HourlyWeather] = []
    @State private var todayForecast: [HourlyWeather] = []
    @State private var heatRuns: [UsualHourRun] = []
    @State private var hotSessions = 0
    @State private var selectedHour: Int?
    @State private var showsEdit = false
    @State private var showsChat = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let row = app.trainer.row(for: iso) {
                    content(row)
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(Day(iso: iso).map(TrainerText.longDate) ?? "")
        .toolbar {
            if let row = app.trainer.row(for: iso), app.trainer.canEdit(row) {
                ToolbarItem(placement: .primaryAction) { Button(TrainerText.editWorkoutButton) { showsEdit = true } }
            }
        }
        .sheet(isPresented: $showsEdit) { TrainerEditWorkoutView(iso: iso) }
        .sheet(isPresented: $showsChat) { TrainerChatSheet() }
        .task(id: iso) {
            guard let day = Day(iso: iso), day == app.trainer.currentDay, app.trainer.row(for: iso)?.run == nil else { return }
            todayForecast = await app.trainer.forecast(for: day)
        }
        .task(id: iso) {
            guard let day = Day(iso: iso), app.trainer.row(for: iso)?.workout.kind == .long else { return }
            let recent = TodayModel.recentRuns(context: app.container.mainContext)
            heatRuns = DayAdjustText.usualRuns(recent)
            hotSessions = ActivityRecord.hotSessions(before: .now, among: recent)
            weather = await app.trainer.forecast(for: day)
        }
    }

    @ViewBuilder
    private func content(_ row: TrainerDayRow) -> some View {
        let heatDay = row.workout.kind == .long && row.run == nil ? TrainerHeatDayBuilder.make(
            weather: weather, longPace: app.trainer.plan?.paces.long, usualHour: longHour, hotSessions: hotSessions
        ) : nil
        let dayAdjust = row.run == nil ? app.trainer.dayAdjusted(row.workout) : nil
        let workout = dayAdjust?.workout ?? displayed(row.workout, heat: heatDay.flatMap { $0.hour(selectedHour ?? $0.usualHour) }?.heat)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(workout.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
                if workout.edited && workout.kind != .off {
                    Text(TrainerText.editedStatus).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
                }
            }
            Text(subtitle(workout)).font(.caption).foregroundStyle(BrandColors.dim)
            if workout.kind != .off {
                numbers(workout, estimate: app.trainer.timeEstimate(workout, run: row.run))
                    .padding(.top, 8)
                if let dayAdjust, let line = TrainerText.dayAdjustLine(dayAdjust) {
                    Text(line).font(.caption).foregroundStyle(BrandColors.attention).monospacedDigit()
                }
                if row.run == nil, row.workout.day == app.trainer.currentDay, let watch = app.trainer.todayWatch {
                    watchPanel(watch)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        if !workout.steps.isEmpty {
            section(TrainerText.structureTitle)
            VStack(alignment: .leading, spacing: 10) {
                TrainerShapeChart(bars: TrainerText.shapeBars(workout.steps))
                TrainerStepList(rows: TrainerText.stepRows(workout), bands: app.trainer.planZones.bands)
            }
            .brandCard()
        }
        if let heatDay {
            TrainerHeatCard(day: heatDay, selected: $selectedHour, hasBlocks: TrainerEngine.plannedPauses(of: workout) > 0)
        }
        section(TrainerText.whyTitle)
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.rationale).font(.footnote).foregroundStyle(BrandColors.text)
            if let method = workout.method {
                Text(TrainerText.methodLine(method)).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        if !row.strength.isEmpty {
            section(TrainerText.strengthDayTitle)
            ForEach(row.strength) { line in
                strengthCard(line)
            }
        }
        if let run = row.run {
            section(TrainerText.doneTitle)
            runCard(run)
        }
        AskIntelligenceButton(title: TrainerChatConstants.ask) { showsChat = true }
    }

    private func watchPanel(_ watch: DayAdjustWatch) -> some View {
        let now = Date.now
        let hour = Calendar.current.component(.hour, from: now)
        let nowEntries = todayForecast.isEmpty ? nil : DayAdjustWatchRules.retimed(watch.entries, forecast: todayForecast, hour: hour, now: now)
        return VStack(alignment: .leading, spacing: DSSpacing.s3) {
            Divider().overlay(BrandColors.line)
            DayAdjustWatchPanel(
                watch: watch, nowEntries: nowEntries,
                later: DayAdjustWatchRules.laterOptions(watch, forecast: todayForecast, currentHour: hour, now: now),
                isBusy: app.trainer.isSendingToGarmin
            ) { entries in
                await app.trainer.sendNowDayAdjust(entries, client: app.garminAccount.client)?.firstError
            }
        }
        .padding(.top, DSSpacing.s2)
    }

    private func section(_ title: String) -> some View {
        DSSectionTitle(title)
            .padding(.top, DSSpacing.sectionTop - TrainerConstants.detailSpacing)
            .padding(.bottom, DSSpacing.sectionBottom - TrainerConstants.detailSpacing)
    }

    @ViewBuilder
    private func strengthCard(_ line: TrainerStrengthLine) -> some View {
        let card = StrengthDayCard(model: app.trainer.strengthDayCard(line, day: Day(iso: iso) ?? app.trainer.currentDay))
        if line.source == .trainer {
            NavigationLink { TrainerStrengthWorkoutView(iso: iso, sessionId: line.id) } label: { card }
                .buttonStyle(.cardLink)
        } else {
            card
        }
    }

    private var longHour: Int {
        let date = Day(iso: iso).flatMap { Calendar.current.date(from: DateComponents(year: $0.year, month: $0.month, day: $0.day, hour: 12)) } ?? .now
        return UsualHour.hour(for: date, long: true, runs: heatRuns, now: .now, calendar: .current)
    }

    private func subtitle(_ workout: TrainerWorkout) -> String {
        var parts = [TrainerText.distance(workout.totalMeters)]
        if let index = app.trainer.weekIndex(of: workout.day) { parts.append("semana \(index) do plano") }
        if let plan = app.trainer.plan, plan.longMode == .blocks, workout.kind == .long, workout.day >= app.trainer.currentDay {
            parts.append(TrainerText.longStageCaption(stage: plan.longStage, streak: plan.longStageStreak))
        }
        return parts.joined(separator: " · ")
    }

    private func displayed(_ workout: TrainerWorkout, heat: TrainerHeat?) -> TrainerWorkout {
        guard let heat, let pace = app.trainer.plan?.paces.long else { return workout }
        return heat.apply(to: workout, longPace: pace)
    }

    private func numbers(_ workout: TrainerWorkout, estimate: RunTimeRange?) -> some View {
        var items = [(TrainerText.distance(workout.totalMeters), TrainerText.plannedLabel)]
        if let range = TrainerText.paceRange(low: workout.paceLow, high: workout.paceHigh) {
            items.append((range, TrainerText.paceLabel))
        }
        if let estimate { items.append((RunTimeText.range(estimate), RunTimeConstants.label)) }
        if let note = workout.note, !note.isEmpty { items.append((note, TrainerText.notePrefix)) }
        return HStack(alignment: .top, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.0).font(BrandFonts.number(17)).foregroundStyle(BrandColors.text).lineLimit(2).minimumScaleFactor(0.7)
                    Text(item.1).font(.caption2).foregroundStyle(BrandColors.dim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func runCard(_ run: TrainerRun) -> some View {
        var items = [(TrainerText.runDistance, TrainerText.distance(run.meters))]
        if let pace = TrainerText.runPace(run) { items.append((TrainerText.runPace, pace)) }
        if let heartRate = run.averageHeartRate { items.append((TrainerText.runHeartRate, "\(Int(heartRate.rounded())) bpm")) }
        if let onTarget = run.activeOnTarget, let total = run.activeTotal { items.append((TrainerText.runOnTarget, "\(onTarget) de \(total)")) }
        if let pauses = run.pauses { items.append((TrainerText.runPauses, "\(pauses)")) }
        if let fade = run.fadeKm { items.append((TrainerText.runFade, "\(fade)")) }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.0).font(.footnote).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(item.1).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.text).monospacedDigit()
                }
            }
            NavigationLink { WorkoutDetailView(activityId: run.activityId) } label: { CardLinkFooter(title: CardLinkConstants.workout) }
                .buttonStyle(.cardLink)
                .padding(.top, 4)
        }
        .brandCard()
    }
}
