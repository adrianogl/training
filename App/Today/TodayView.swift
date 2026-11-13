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

    private var syncToken: Date? {
        if case .finished(let date) = app.syncStatus { return date }
        return nil
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CompactLogoHeader()
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(WorkoutConstants.locale)))
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
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
                    if let model {
                        cards(model)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .onChange(of: model?.isLoaded) { _, loaded in
                guard loaded == true, Self.debugScrollsToEnd() else { return }
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    proxy.scrollTo(TodayConstants.endAnchor, anchor: .bottom)
                }
            }
            }
            .background(BrandBackground())
            .refreshable { await app.syncNow(.pull) }
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
        .task(id: syncToken) {
            await Task.yield()
            let loaded = TodayModel(container: app.container, today: Day.today())
            await loaded.load()
            model = loaded
            await loaded.refreshSentence()
        }
    }

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
            WeekCalendarCard(runs: model.weekRuns, today: model.today, goal: weeklyGoal)
            VolumeHistoryCard(week: model.summary.week, goal: weeklyGoal)
            row(weights: [1, 1]) {
                if let lastRun = model.lastRun {
                    LastRunCard(lastRun: lastRun)
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
