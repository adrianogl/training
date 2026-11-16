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
    @State private var strength = StrengthModel()

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
                        .font(BrandFonts.largeTitle)
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
                    if let model { ReadinessDetailView(model: model, recovery: model.recoveryEstimate(trainer: trainerWorkouts)) }
                case .workout(let id):
                    WorkoutDetailView(activityId: id)
                case .week:
                    if let model { TodayWeekDetailView(model: model, trainer: trainerWorkouts, goal: weeklyGoal) }
                case .lastRun:
                    if let model, let lastRun = model.lastRun {
                        LastRunDetailView(lastRun: lastRun, plannedKm: model.lastRunPlannedKm(trainer: trainerWorkouts))
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
            if let sunday = WeeklyReportBuilder.nextSunday(after: .now) {
                await UserNotificationScheduler().schedule(id: WeeklyReportConstants.notificationId, text: loaded.currentWeekReport(trainer: app.trainer.activeWorkouts).notification, at: sunday)
            }
            await loaded.refreshSentence()
        }
        .task(id: app.dataToken) {
            await app.trainer.load()
            await strength.load(container: app.container, client: app.mfitAccount.client, plan: app.trainer.plan)
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

    @ViewBuilder
    private func cards(_ model: TodayModel) -> some View {
        let spacing = TodayConstants.rowSpacing
        if sizeClass == .regular {
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

    @ViewBuilder
    private func nowBlock(_ model: TodayModel) -> some View {
        blockLabel(TodayConstants.blockNow, first: true)
        ReadinessHeroCard(model: model, overload: model.overload, recovery: model.recoveryEstimate(trainer: trainerWorkouts))
    }

    @ViewBuilder
    private func todayBlock(_ model: TodayModel) -> some View {
        if let pick = workoutPick(model) {
            blockLabel(TodayConstants.blockToday)
            TodayWorkoutCard(model: model, trainer: app.trainer, pick: pick)
        }
        TodayStrengthCard(showsLabel: workoutPick(model) == nil) {
            blockLabel(TodayConstants.blockToday)
        }
    }

    @ViewBuilder
    private func weekBlock(_ model: TodayModel) -> some View {
        blockLabel(TodayConstants.blockWeek, first: sizeClass == .regular)
        let report = model.shownWeekReport(trainer: trainerWorkouts)
        let isCurrentWeek = report.start == Day.today().weekStart
        TodayWeekCard(
            report: report,
            isClosed: model.shownWeek.isClosed,
            series: model.volumeSeries,
            strength: isCurrentWeek ? strength.weekTitles : [:],
            warnings: isCurrentWeek ? strength.warnings : []
        )
        if let lastRun = model.lastRun {
            LastRunCompactCard(lastRun: lastRun, plannedKm: model.lastRunPlannedKm(trainer: trainerWorkouts))
        }
    }

    @ViewBuilder
    private func outlookBlock(_ model: TodayModel) -> some View {
        blockLabel(TodayConstants.blockOutlook)
        TodayOutlookCard(model: model).id(TodayConstants.endAnchor)
    }

    private func blockLabel(_ text: String, first: Bool = false) -> some View {
        SectionHeader(text)
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
