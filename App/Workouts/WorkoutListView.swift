import GarminAPI
import MFIT
import Storage
import SwiftData
import SwiftUI
import TrainingCore

struct WorkoutListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var availableWidth: CGFloat = 0
    @Query(sort: \ActivityRecord.start, order: .reverse) private var records: [ActivityRecord]
    @SceneStorage(NavigationRestorationConstants.workoutsPathKey) private var pathData = Data()
    @SceneStorage(NavigationRestorationConstants.workoutsSelectionKey) private var selectionData = Data()
    @State private var appliedRestoration = false
    @State private var chatCounts: [Int64: Int] = [:]
    @State private var planned: [PlannedWorkout] = []
    @State private var userScrolled = false
    @State private var showsPlanned = false
    @State private var plannedWeeks: [Day: Double] = [:]
    @State private var kindFilter: WorkoutKindFilter = .all
    @State private var strengthPlanned: [StrengthWorkout] = []
    @State private var strengthDoneDays: Set<String> = []
    @State private var strengthProgram: MFITProgram?

    @State private var path: [WorkoutSelection] = []
    @State private var selection: WorkoutSelection?

    private func isRestorable(_ item: WorkoutSelection) -> Bool {
        guard case .activity(let id) = item else { return true }
        return records.contains { $0.activityId == id }
    }

    private func validated(_ items: [WorkoutSelection]) -> [WorkoutSelection] {
        NavigationRestoration.validPrefix(items, isValid: isRestorable)
    }

    private var isSplit: Bool {
        sizeClass == .regular && availableWidth >= WorkoutConstants.splitMinWidth
    }

    var body: some View {
        let allWeeks = WorkoutListModel.weeks(records: records, plannedKilometers: plannedWeeks)
        let weeks = WorkoutListModel.filtered(allWeeks, by: kindFilter)
        let visibility = WorkoutListModel.visiblePlanned(planned: planned, rows: allWeeks.flatMap(\.rows).filter { !$0.isStrength }, from: Day.today().iso)
        let doneDays = strengthDoneDays.union(allWeeks.flatMap(\.rows).filter(\.isStrength).map(\.dayIso))
        let plannedItems = WorkoutListModel.plannedItems(runs: visibility.visible, strength: strengthPlanned, doneStrengthDays: doneDays, filter: kindFilter)
        Group {
            if isSplit {
                HStack(spacing: 0) {
                    list(weeks, hasRuns: !allWeeks.isEmpty, visibility: visibility, plannedItems: plannedItems)
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
                    list(weeks, hasRuns: !allWeeks.isEmpty, visibility: visibility, plannedItems: plannedItems)
                        .navigationDestination(for: WorkoutSelection.self) { item in destination(item) }
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .onAppear(perform: applyRestoration)
        .onChange(of: path) { _, value in pathData = NavigationRestoration.encode(value) }
        .onChange(of: selection) { _, value in selectionData = value.map { NavigationRestoration.encode($0) } ?? Data() }
        .task {
            model.scoreRefresher.refresh()
        }
        .task(id: selection) {
            chatCounts = await WorkoutChatStore.shared.questionCounts()
        }
        .task(id: model.mfitAccount.revision) {
            guard model.mfitAccount.isSignedIn else { strengthPlanned = []; strengthDoneDays = []; strengthProgram = nil; return }
            let today = Day.today()
            let store = StrengthProgramStore()
            applyStrength(store.load(), today: today)
            guard let client = model.mfitAccount.client,
                  let fetched = try? await client.currentProgram(today: today.iso) as MFITProgram?? else { return }
            applyStrength(fetched.map(store.update(with:)) ?? store.clearProgram(), today: today)
        }
        .task(id: model.garminAccount.isSignedIn) {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: AppConstants.samplePlannedDefaultsKey) {
                planned = PlannedSamples.week(from: Day.today())
                updatePlannedWeeks()
                return
            }
            #endif
            guard let client = model.garminAccount.client else { planned = []; updatePlannedWeeks(); return }
            let today = Day.today()
            planned = (try? await PlannedWorkouts.fetch(client: client, from: today.weekStart, through: today.adding(days: WorkoutConstants.plannedDays))) ?? []
            updatePlannedWeeks()
            dropMissingPlanned()
        }
    }

    private func applyRestoration() {
        guard !appliedRestoration else { return }
        appliedRestoration = true
        path = validated(NavigationRestoration.decodePath(pathData))
        selection = NavigationRestoration.decodeValue(selectionData).flatMap { isRestorable($0) ? $0 : nil }
        let debugPath = Self.initialPath()
        guard !debugPath.isEmpty else { return }
        path = debugPath
        selection = debugPath.first
    }

    private func applyStrength(_ cache: StrengthProgramCache, today: Day) {
        strengthProgram = cache.program
        strengthPlanned = StrengthSchedule().workouts(cache.program, from: today, through: today.adding(days: WorkoutConstants.plannedDays))
        strengthDoneDays = Set(cache.known.flatMap { $0.completions.map(\.day) })
    }

    private func updatePlannedWeeks() {
        let cached = model.scope.defaults.dictionary(forKey: AppConstants.plannedWeeksDefaultsKey) as? [String: Double] ?? [:]
        plannedWeeks = WorkoutListModel.plannedKilometers(planned: planned, cached: cached)
    }

    private func dropMissingPlanned() {
        let plannedIds = Set(planned.map(\.id))
        let isPresent: (WorkoutSelection) -> Bool = { item in
            guard case .planned(let id) = item else { return true }
            return plannedIds.contains(id)
        }
        let kept = NavigationRestoration.validPrefix(path, isValid: isPresent)
        if kept.count != path.count { path = kept }
        if let current = selection, !isPresent(current) { selection = nil }
    }

    private func current(_ weeks: [WorkoutWeek]) -> WorkoutSelection? {
        selection ?? weeks.first?.rows.first.map { .activity($0.activityId) }
    }

    @ViewBuilder
    private func destination(_ item: WorkoutSelection) -> some View {
        switch item {
        case .activity(let id):
            if records.contains(where: { $0.activityId == id && ActivityTypeKey.isStrength($0.typeKey) }) {
                StrengthActivityDetailView(activityId: id)
            } else {
                WorkoutDetailView(activityId: id)
            }
        case .planned(let id):
            if let plan = planned.first(where: { $0.id == id }) {
                PlannedWorkoutDetailView(plan: plan, week: planned)
            }
        case .strength(let id):
            StrengthPlannedDetailView(workoutId: id)
        }
    }

    private func list(_ weeks: [WorkoutWeek], hasRuns: Bool, visibility: PlannedVisibility, plannedItems: [WorkoutPlannedItem]) -> some View {
        let selected = current(weeks)
        let today = Day.today().iso
        return ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                CompactLogoHeader()
                Text(WorkoutConstants.listTitle)
                    .font(BrandFonts.largeTitle)
                    .foregroundStyle(BrandColors.text)
                SyncStatusPill()
                if hasRuns {
                    WorkoutKindFilterBar(selection: $kindFilter)
                }
                if kindFilter == .strength, let program = strengthProgram {
                    Text(StrengthText.programLabel(program.title, start: program.start.flatMap(Day.init(iso:)), end: program.end.flatMap(Day.init(iso:))) + WorkoutConstants.programSource)
                        .font(BrandFonts.number(12))
                        .foregroundStyle(BrandColors.dim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .overlay(Capsule().strokeBorder(BrandColors.line))
                }
                if !plannedItems.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showsPlanned.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(String(format: WorkoutConstants.plannedHeaderFormat, WorkoutConstants.plannedTitle, plannedItems.count))
                                .font(.caption)
                                .foregroundStyle(BrandColors.dim)
                            Image(systemName: showsPlanned ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BrandColors.dim)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    if showsPlanned {
                        ForEach(plannedItems) { item in
                            plannedRow(item, today: today, selected: selected)
                        }
                    }
                }
                if weeks.isEmpty && model.showsSkeleton {
                    FirstSyncView()
                } else if weeks.isEmpty && hasRuns {
                    Text(WorkoutConstants.emptyFilter)
                        .foregroundStyle(BrandColors.dim)
                        .brandCard()
                } else if weeks.isEmpty {
                    Text(WorkoutConstants.emptyList)
                        .foregroundStyle(BrandColors.dim)
                        .brandCard()
                }
                ForEach(weeks) { week in
                    VStack(alignment: .leading, spacing: 10) {
                        if week.id == weeks.first?.id && !plannedItems.isEmpty && showsPlanned {
                            Text(WorkoutConstants.upcomingMarker)
                                .font(.caption2)
                                .foregroundStyle(BrandColors.dim)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        HStack {
                            Text(WorkoutListModel.weekLabel(week.start))
                            Spacer()
                            Text(WorkoutListModel.weekSummary(week))
                        }
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                        if let progress = week.plannedProgress {
                            weekBar(progress)
                        }
                    }
                    .padding(.top, 8)
                    .id(week.id == weeks.first?.id ? WorkoutConstants.listTopAnchor : nil)
                    ForEach(week.rows) { row in
                        link(.activity(row.activityId)) {
                            WorkoutRow(row: row, isSelected: isSplit && selected == .activity(row.activityId), hasChat: (chatCounts[row.activityId] ?? 0) > 0, isFromPlan: visibility.fromPlanIds.contains(row.activityId), isNew: model.newActivityIds.contains(row.activityId))
                        }
                    }
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 24)
        }
        .brandRefreshable { await model.syncNow(.pull) }
        .background(BrandBackground())
        .onScrollPhaseChange { _, phase in
            if phase == .interacting { userScrolled = true }
        }
        .onAppear { scrollToLatest(proxy) }
        .onChange(of: weeks.first?.id) { scrollToLatest(proxy) }
        .onChange(of: plannedItems.map(\.id)) { scrollToLatest(proxy) }
        .toolbarVisibility(isSplit ? .automatic : .hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func plannedRow(_ item: WorkoutPlannedItem, today: String, selected: WorkoutSelection?) -> some View {
        switch item {
        case .run(let plan):
            link(.planned(plan.id)) {
                PlannedWorkoutRow(plan: plan, isToday: plan.day == today, isSelected: selected == .planned(plan.id))
            }
        case .strength(let workout):
            link(.strength(workout.id)) {
                StrengthPlannedRow(workout: workout, isToday: workout.day == today, isSelected: selected == .strength(workout.id))
            }
        }
    }

    private func weekBar(_ progress: Double) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(BrandColors.accentFill)
                .frame(width: max(WorkoutConstants.weekBarHeight, proxy.size.width * progress))
        }
        .frame(height: WorkoutConstants.weekBarHeight)
        .background(BrandColors.track, in: Capsule())
        .padding(.top, -4)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard !userScrolled else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(WorkoutConstants.listTopAnchor, anchor: .top)
        }
    }

    @ViewBuilder
    private func link<Label: View>(_ item: WorkoutSelection, @ViewBuilder label: () -> Label) -> some View {
        if isSplit {
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
