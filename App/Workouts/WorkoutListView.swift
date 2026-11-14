import GarminAPI
import Storage
import SwiftData
import SwiftUI
import TrainingCore

struct WorkoutListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \ActivityRecord.start, order: .reverse) private var records: [ActivityRecord]
    @State private var path = WorkoutListView.initialPath()
    @State private var chatCounts: [Int64: Int] = [:]
    @State private var selection: WorkoutSelection? = WorkoutListView.initialPath().first
    @State private var planned: [PlannedWorkout] = []

    var body: some View {
        let weeks = WorkoutListModel.weeks(records: records)
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    list(weeks)
                        .frame(width: WorkoutConstants.listWidth)
                    Divider().overlay(BrandColors.line)
                    NavigationStack {
                        if let current = current(weeks) {
                            destination(current).id(current)
                        } else {
                            Text(WorkoutConstants.selectWorkout)
                                .foregroundStyle(BrandColors.dim)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(BrandBackground())
                        }
                    }
                }
            } else {
                NavigationStack(path: $path) {
                    list(weeks)
                        .navigationDestination(for: WorkoutSelection.self) { item in destination(item) }
                }
            }
        }
        .task {
            model.scoreRefresher.refresh()
        }
        .task(id: selection) {
            chatCounts = await WorkoutChatStore.shared.questionCounts()
        }
        .task(id: model.garminAccount.isSignedIn) {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: AppConstants.samplePlannedDefaultsKey) {
                planned = PlannedSamples.week(from: Day.today())
                return
            }
            #endif
            guard let client = model.garminAccount.client else { planned = []; return }
            let today = Day.today()
            planned = (try? await PlannedWorkouts.fetch(client: client, from: today, through: today.adding(days: WorkoutConstants.plannedDays))) ?? []
        }
    }

    private func current(_ weeks: [WorkoutWeek]) -> WorkoutSelection? {
        selection ?? weeks.first?.rows.first.map { .activity($0.activityId) }
    }

    @ViewBuilder
    private func destination(_ item: WorkoutSelection) -> some View {
        switch item {
        case .activity(let id):
            WorkoutDetailView(activityId: id)
        case .planned(let id):
            if let plan = planned.first(where: { $0.id == id }) {
                PlannedWorkoutDetailView(plan: plan, week: planned)
            }
        }
    }

    private func list(_ weeks: [WorkoutWeek]) -> some View {
        let selected = current(weeks)
        let today = Day.today().iso
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                CompactLogoHeader()
                Text(WorkoutConstants.listTitle)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(BrandColors.text)
                if case .running(let progress) = model.syncStatus {
                    ProgressView(value: progress) {
                        Text("Sincronizando com o Garmin")
                            .font(.caption)
                            .foregroundStyle(BrandColors.dim)
                    }
                }
                if !planned.isEmpty {
                    Text(WorkoutConstants.plannedTitle)
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                        .padding(.top, 8)
                    ForEach(planned) { plan in
                        link(.planned(plan.id)) {
                            PlannedWorkoutRow(plan: plan, isToday: plan.day == today, isSelected: selected == .planned(plan.id))
                        }
                    }
                }
                if weeks.isEmpty {
                    Text(WorkoutConstants.emptyList)
                        .foregroundStyle(BrandColors.dim)
                        .brandCard()
                }
                ForEach(weeks) { week in
                    HStack {
                        Text(WorkoutListModel.weekLabel(week.start))
                        Spacer()
                        Text(WorkoutListModel.weekSummary(week))
                    }
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                    .padding(.top, 8)
                    ForEach(week.rows) { row in
                        link(.activity(row.activityId)) {
                            WorkoutRow(row: row, isSelected: sizeClass == .regular && selected == .activity(row.activityId), hasChat: (chatCounts[row.activityId] ?? 0) > 0)
                        }
                    }
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .refreshable { await model.syncNow(.pull) }
        .toolbarVisibility(sizeClass == .regular ? .automatic : .hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func link<Label: View>(_ item: WorkoutSelection, @ViewBuilder label: () -> Label) -> some View {
        if sizeClass == .regular {
            Button { selection = item } label: { label() }
                .buttonStyle(.plain)
        } else {
            NavigationLink(value: item) { label() }
                .buttonStyle(.plain)
        }
    }

    private static func initialPath(defaults: UserDefaults = .standard) -> [WorkoutSelection] {
        #if DEBUG
        if let planId = defaults.object(forKey: AppConstants.openPlannedDefaultsKey).flatMap({ "\($0)" }).flatMap(Int64.init) {
            return [.planned(planId)]
        }
        let activityId = defaults.object(forKey: AppConstants.openActivityDefaultsKey).flatMap { "\($0)" }.flatMap(Int64.init)
        return activityId.map { [.activity($0)] } ?? []
        #else
        return []
        #endif
    }
}
