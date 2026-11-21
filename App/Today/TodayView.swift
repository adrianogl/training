import Insights
import SwiftData
import SwiftUI
import TrainingCore

struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var contentWidth: Double = 0
    @AppStorage(AppConstants.weeklyGoalDefaultsKey) private var weeklyGoal = 0
    @Binding var path: [TodayRoute]
    var openSettings: () -> Void = {}
    @State private var model: TodayModel?
    @State private var strength = StrengthModel()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DSScreenHeader(title: TodayConstants.todayTitle, subtitle: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(WorkoutConstants.locale))) {
                        SyncStatusPill()
                        if model?.isStale == true { RefreshingLabel() }
                        if let chip = app.remoteSync.chip { RemoteSyncChipView(chip: chip, action: openSettings) }
                    }
                    .padding(.bottom, DSSpacing.s2)
                    if let storeError = app.storeError {
                        Text("Não abriu o banco local, o app está usando memória: \(storeError)")
                            .font(.footnote)
                            .foregroundStyle(BrandColors.danger)
                            .padding(.bottom, 14)
                    }
                    if app.installExpiry.showsNotice {
                        InstallExpiryNotice(title: app.installExpiry.title, text: app.installExpiry.text)
                            .padding(.bottom, DSSpacing.s3)
                    }
                    if app.installNotice.showsCard, let card = app.installNotice.card {
                        InstalledNotice(card: card, dismiss: app.installNotice.dismiss)
                            .padding(.bottom, DSSpacing.s3)
                    }
                    if app.appUpdate.showsNotice, let update = app.appUpdate.update {
                        AppUpdateNotice(update: update, openSettings: openSettings, dismiss: app.appUpdate.dismiss)
                            .padding(.bottom, DSSpacing.s3)
                    }
                    if let model, model.isLoaded, !app.showsSkeleton {
                        cards(model)
                            .onGeometryChange(for: Double.self) { $0.size.width } action: { contentWidth = $0 }
                    } else if app.showsSkeleton {
                        FirstSyncView()
                    } else {
                        SkeletonCards(heights: SkeletonConstants.todayHeights)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .brandRefreshable { await app.syncNow(.pull) }
            .onChange(of: model?.isLoaded) { _, loaded in
                guard loaded == true, Self.debugScrollsToEnd() else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    proxy.scrollTo(TodayConstants.endAnchor, anchor: .bottom)
                }
            }
            }
            .background(BrandBackground())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: TodayRoute.self) { route in
                switch route {
                case .readiness:
                    if let model { ReadinessDetailView(model: model, recovery: model.recoveryEstimate(trainer: trainerWorkouts)) }
                case .workout(let id):
                    WorkoutDetailView(activityId: id)
                case .week:
                    if let model { TodayWeekDetailView(model: model, trainer: trainerWorkouts, goal: weeklyGoal, strength: strength) }
                case .lastRun:
                    if let model, let lastRun = model.lastRun {
                        LastRunDetailView(lastRun: lastRun, plannedKm: model.lastRunPlannedKm(trainer: trainerWorkouts))
                    }
                case .planned(let id):
                    if let model, let plan = model.planned.values.joined().first(where: { $0.id == id }) {
                        PlannedWorkoutDetailView(plan: plan, week: model.planned.values.joined().sorted { $0.day < $1.day })
                    }
                }
            }
        }
        .task(id: app.dataToken) {
            await Task.yield()
            if model == nil {
                model = await TodayModel.restored(container: app.container, snapshots: app.snapshots)
            }
            let loaded = TodayModel(container: app.container, today: Day.today(), snapshots: app.snapshots)
            await loaded.load()
            guard !Task.isCancelled else { return }
            model = loaded
            await loaded.loadGarminReadiness(client: app.garminAccount.client)
            await loaded.loadPlanned(client: app.garminAccount.client)
            await loaded.loadPlannedHistory(client: app.garminAccount.client)
            await scheduleWeeklyReport()
            writeWidgetSnapshot()
            await loaded.refreshSentence()
            writeWidgetSnapshot()
        }
        .task(id: app.dataToken) {
            await app.trainer.load()
            if app.trainer.plan == nil {
                await app.trainer.loadExternal(client: app.garminAccount.client)
            }
            await strength.load(container: app.container, client: app.mfitAccount.client, plan: app.trainer.plan, garmin: app.garminAccount.client)
            await scheduleWeeklyReport()
            writeWidgetSnapshot()
            if app.mfitAccount.isSignedIn {
                await app.trainer.syncStrength(TrainerMFITStrength.sessions(program: strength.program, schedule: StrengthSchedule()))
            }
        }
        .task(id: app.mfitAccount.revision) {
            await strength.load(container: app.container, client: app.mfitAccount.client, plan: app.trainer.plan)
        }
        .task(id: app.garminAccount.isSignedIn) {
            guard let model, app.garminAccount.isSignedIn else { return }
            await model.loadGarminReadiness(client: app.garminAccount.client)
            await model.loadPlanned(client: app.garminAccount.client)
            await model.loadPlannedHistory(client: app.garminAccount.client)
        }
    }

    private var trainerWorkouts: [TrainerWorkout] { app.trainer.activeWorkouts }

    private func writeWidgetSnapshot() {
        guard let model, model.isLoaded else { return }
        let report = model.currentWeekReport(trainer: app.trainer.activeWorkouts)
        var title: String?
        var detail: String?
        switch workoutPick(model)?.today {
        case .garmin(let plan): title = plan.title; detail = PlanText.estimate(plan, fallback: app.trainer.easyPaceBand)
        case .trainer(let row): title = row.workout.title; detail = "\(TodayText.decimal(row.workout.totalMeters / 1_000, fractionDigits: 1)) km"
        case nil: break
        }
        WidgetSnapshotWriter.write(WidgetSnapshot(
            score: model.summary.readiness?.score ?? model.fallbackScore,
            verdict: model.summary.verdict.flatMap { TodayConstants.verdictPhrases[$0] },
            readinessLine: WidgetSnapshotWriter.firstSentence(model.readinessSentence),
            workoutTitle: title,
            workoutDetail: detail,
            strengthTitle: strength.weekWorkouts.first { $0.day == model.today.iso }.map { StrengthText.shortTitle($0.title) },
            raceName: report.race?.name,
            raceDays: report.race?.days,
            weekText: report.plannedKm.map { "Semana: \(TodayText.decimal(report.doneKm, fractionDigits: 0)) de \(TodayText.decimal($0, fractionDigits: 0)) km" },
            updatedAt: .now
        ))
    }

    private func scheduleWeeklyReport() async {
        guard let model, model.isLoaded, let sunday = WeeklyReportBuilder.nextSunday(after: .now) else { return }
        let report = model.currentWeekReport(trainer: app.trainer.activeWorkouts)
        let text = WeeklyReportBuilder.notification(report, strength: strength.weekSummary(start: report.start).map(StrengthText.reportNotification))
        await UserNotificationScheduler().schedule(id: WeeklyReportConstants.notificationId, text: text, at: sunday)
    }

    private var twoColumns: Bool {
        sizeClass == .regular && contentWidth >= TodayConstants.twoColumnMinWidth
    }

    @ViewBuilder
    private func cards(_ model: TodayModel) -> some View {
        let spacing = TodayConstants.rowSpacing
        if twoColumns {
            ProportionalHStack(weights: [1, 1], spacing: spacing) {
                VStack(alignment: .leading, spacing: spacing) {
                    nowBlock(model)
                    todayBlock(model)
                }
                .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: spacing) {
                    weekBlock(model)
                    outlookBlock(model)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                nowBlock(model)
                todayBlock(model)
                weekBlock(model)
                outlookBlock(model)
            }
        }
    }

    private func legDay(_ model: TodayModel) -> StrengthLegDay? {
        strength.legDay(before: model.today, planned: app.trainer.plannedLegs(on: model.today.adding(days: -1)))
    }

    @ViewBuilder
    private func nowBlock(_ model: TodayModel) -> some View {
        blockLabel(TodayConstants.blockNow, first: true)
        ReadinessHeroCard(model: model, overload: model.overload, recovery: model.recoveryEstimate(trainer: trainerWorkouts), legDay: legDay(model))
            .syncSkeleton(app.isRefreshing && model.summary.readinessFromYesterday && model.summary.readinessMissingNight != true, height: SkeletonConstants.readinessHeight)
    }

    @ViewBuilder
    private func todayBlock(_ model: TodayModel) -> some View {
        if !model.plannedLoaded || !strength.isLoaded || !app.trainer.isLoaded {
            blockLabel(TodayConstants.blockToday)
            SkeletonCards(heights: [SkeletonConstants.todayWorkoutHeight])
        } else if let pick = workoutPick(model) {
            blockLabel(TodayConstants.blockToday)
            TodayWorkoutCard(model: model, trainer: app.trainer, pick: pick, legDay: legDay(model))
        }
        if model.plannedLoaded && strength.isLoaded && app.trainer.isLoaded {
            TodayStrengthCard(showsLabel: workoutPick(model) == nil) {
                blockLabel(TodayConstants.blockToday)
            }
        }
    }

    @ViewBuilder
    private func weekBlock(_ model: TodayModel) -> some View {
        blockLabel(TodayConstants.blockWeek, first: twoColumns)
        let report = model.shownWeekReport(trainer: trainerWorkouts)
        let isCurrentWeek = report.start == Day.today().weekStart
        TodayWeekCard(
            report: report,
            isClosed: model.shownWeek.isClosed,
            series: model.volumeSeries,
            strength: isCurrentWeek ? strength.weekTitles : [:],
            warnings: isCurrentWeek ? strength.warnings : []
        )
        .syncSkeleton(app.isRefreshing, height: SkeletonConstants.weekHeight)
        if let lastRun = model.lastRun {
            LastRunCompactCard(lastRun: lastRun, plannedKm: model.lastRunPlannedKm(trainer: trainerWorkouts))
                .syncSkeleton(app.isRefreshing, height: SkeletonConstants.lastRunHeight)
        }
    }

    @ViewBuilder
    private func outlookBlock(_ model: TodayModel) -> some View {
        blockLabel(TodayConstants.blockOutlook)
        TodayOutlookCard(model: model)
            .syncSkeleton(app.isRefreshing, height: SkeletonConstants.outlookHeight)
            .id(TodayConstants.endAnchor)
    }

    private func blockLabel(_ text: String, first: Bool = false) -> some View {
        DSSectionTitle(text).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
            .padding(.top, first ? -TodayConstants.blockLabelTopInset : 0)
            .padding(.bottom, -TodayConstants.blockLabelBottomInset)
    }

    private func workoutPick(_ model: TodayModel) -> TodayWorkoutPick? {
        let trainer = app.trainer
        return TodayWorkoutPicker.pick(
            garminToday: model.todayPlan,
            trainerToday: trainer.todayRow(for: model.today),
            garminTomorrow: model.tomorrowPlan,
            trainerTomorrow: trainer.todayRow(for: model.today.adding(days: 1))
        )
    }

    private static func debugScrollsToEnd(defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return defaults.bool(forKey: AppConstants.todayScrollDefaultsKey)
        #else
        return false
        #endif
    }
}
