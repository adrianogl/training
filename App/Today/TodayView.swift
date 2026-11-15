import Insights
import SwiftData
import SwiftUI
import TrainingCore

struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(AppConstants.weeklyGoalDefaultsKey) private var weeklyGoal = 0
    @Binding var path: [TodayRoute]
    var openSettings: () -> Void = {}
    @State private var model: TodayModel?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CompactLogoHeader()
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(WorkoutConstants.locale)))
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                    SyncStatusPill()
                        .padding(.top, 6)
                    if model?.isStale == true {
                        RefreshingLabel()
                            .padding(.top, 6)
                    }
                    if let chip = app.remoteSync.chip {
                        RemoteSyncChipView(chip: chip, action: openSettings)
                            .padding(.top, 6)
                    }
                    Text(TodayConstants.todayTitle)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(BrandColors.text)
                        .padding(.bottom, 14)
                    if let storeError = app.storeError {
                        Text("Não abriu o banco local, o app está usando memória: \(storeError)")
                            .font(.footnote)
                            .foregroundStyle(BrandColors.danger)
                            .padding(.bottom, 14)
                    }
                    if let model, model.isLoaded, !app.showsSkeleton {
                        cards(model)
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
                    if let model { ReadinessDetailView(model: model) }
                case .workout(let id):
                    WorkoutDetailView(activityId: id)
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
            if let sunday = WeeklyReportBuilder.nextSunday(after: .now) {
                await UserNotificationScheduler().schedule(id: WeeklyReportConstants.notificationId, text: loaded.currentWeekReport(trainer: app.trainer.plan?.workouts ?? []).notification, at: sunday)
            }
            await loaded.refreshSentence()
        }
        .task(id: app.dataToken) {
            await app.trainer.load()
        }
        .task(id: app.garminAccount.isSignedIn) {
            guard let model, app.garminAccount.isSignedIn else { return }
            await model.loadGarminReadiness(client: app.garminAccount.client)
            await model.loadPlanned(client: app.garminAccount.client)
            await model.loadPlannedHistory(client: app.garminAccount.client)
        }
    }

    private var trainerWorkouts: [TrainerWorkout] { app.trainer.plan?.workouts ?? [] }

    @ViewBuilder
    private func cards(_ model: TodayModel) -> some View {
        let spacing = TodayConstants.rowSpacing
        VStack(alignment: .leading, spacing: spacing) {
            if let days = model.summary.raceCountdownDays {
                row(weights: TodayConstants.topRowWeights) {
                    ReadinessHeroCard(model: model)
                    RaceCountdownCard(model: model, days: days)
                }
            } else {
                ReadinessHeroCard(model: model)
            }
            TrainerTodayCard(
                trainer: app.trainer, score: model.summary.readiness?.score ?? model.fallbackScore,
                factor: TrainerModel.lowestFactor(model.summary.readiness)
            )
            if !model.goals.isEmpty {
                GoalsCard(snapshots: model.goals)
            }
            if let plan = model.todayPlan {
                TodayPlanCard(plan: plan, verdict: model.summary.verdict)
            }
            if let overload = model.overload {
                OverloadCard(alert: overload)
            }
            if let report = model.weeklyReport(trainer: trainerWorkouts) {
                WeeklyReportCard(report: report)
            }
            if let run = model.recoveryRun {
                RecoveryCard(
                    estimate: RecoveryEstimator.estimate(run: run, readiness: model.summary.readiness?.score, sessions: model.plannedSessions(trainer: trainerWorkouts), now: .now)
                )
            }
            WeekCalendarCard(runs: model.weekRuns, today: model.today, goal: weeklyGoal, planned: model.planned)
            VolumeHistoryCard(week: model.summary.week, goal: weeklyGoal, planned: model.plannedWeeks)
            row(weights: [1, 1]) {
                if let lastRun = model.lastRun {
                    LastRunCard(lastRun: lastRun, plannedKm: model.lastRunPlannedKm(trainer: trainerWorkouts))
                }
                PredictionsCard(predictions: model.summary.predictions)
            }
            SectionLabel(TodayConstants.trendTitle)
            FitnessCard(model: model).id(TodayConstants.endAnchor)
        }
    }

    @ViewBuilder
    private func row<Content: View>(weights: [Double], @ViewBuilder content: () -> Content) -> some View {
        if sizeClass == .regular {
            ProportionalHStack(weights: weights, spacing: TodayConstants.rowSpacing) { content() }
        } else {
            VStack(spacing: TodayConstants.rowSpacing) { content() }
        }
    }

    private static func debugScrollsToEnd(defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return defaults.bool(forKey: AppConstants.todayScrollDefaultsKey)
        #else
        return false
        #endif
    }
}
