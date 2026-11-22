import GarminAPI
import Insights
import MFIT
import Storage
import SwiftData
import SwiftUI
import WorkoutAnalysis
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
    @State private var weeksCache = WorkoutWeeksCache()
    @State private var activeGoals: [GoalSnapshot] = []
    @State private var trainerPlanned: [TrainerPlannedStrength] = []
    @AppStorage(WorkoutCalendarConstants.modeKey) private var modeRaw = WorkoutListMode.list.rawValue
    @State private var calendarMonth = WorkoutCalendarModel.monthStart(Day.today())
    @State private var calendarDay = Day.today()

    private var mode: WorkoutListMode { WorkoutListMode(rawValue: modeRaw) ?? .list }

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
        let allWeeks = weeksCache.weeks(records: records, goals: activeGoals, plannedKilometers: plannedWeeks)
        let weeks = WorkoutListModel.filtered(allWeeks, by: kindFilter)
        let visibility = WorkoutListModel.visiblePlanned(planned: planned, rows: allWeeks.flatMap(\.rows).filter { !$0.isStrength }, from: Day.today().iso)
        let doneDays = strengthDoneDays.union(allWeeks.flatMap(\.rows).filter(\.isStrength).map(\.dayIso))
        let plannedItems = WorkoutListModel.plannedItems(runs: visibility.visible, strength: strengthPlanned + trainerPlanned.map(\.workout), doneStrengthDays: doneDays, filter: kindFilter)
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
        .onChange(of: DeepLinkCenter.shared.pending, initial: true) { _, _ in openLinkedWorkout() }
        .onChange(of: path) { _, value in pathData = NavigationRestoration.encode(value) }
        .onChange(of: selection) { _, value in selectionData = value.map { NavigationRestoration.encode($0) } ?? Data() }
        .task {
            model.scoreRefresher.refresh()
        }
        .task(id: records.count) {
            activeGoals = (try? goalSnapshots(context: ModelContext(model.container), today: Day.today())) ?? []
        }
        .task(id: selection) {
            chatCounts = await WorkoutChatStore.shared.questionCounts()
        }
        .task(id: trainerPlannedKey) { refreshTrainerPlanned() }
        .onAppear { refreshTrainerPlanned() }
        .task(id: model.mfitAccount.revision) {
            guard model.mfitAccount.isSignedIn else { strengthPlanned = []; strengthDoneDays = []; strengthProgram = nil; return }
            let today = Day.today()
            let store = StrengthProgramStore()
            applyStrength(store.load(), today: today)
            guard let client = model.mfitAccount.client,
                  let fetched = try? await client.currentProgram(today: today.iso) as MFITProgram?? else { return }
            applyStrength(fetched.map(store.update(with:)) ?? store.clearProgram(), today: today)
        }
        .task(id: "\(model.garminAccount.isSignedIn)|\(model.trainer.sendLastDay.iso)") {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: AppConstants.samplePlannedDefaultsKey) {
                planned = PlannedSamples.week(from: Day.today())
                updatePlannedWeeks()
                return
            }
            #endif
            guard let client = model.garminAccount.client else { planned = []; updatePlannedWeeks(); return }
            let today = Day.today()
            let last = min(model.trainer.sendLastDay, today.adding(days: WorkoutConstants.plannedMaxDays))
            planned = (try? await PlannedWorkouts.fetch(client: client, from: today.weekStart, through: last, ignoring: TrainerSendStore().settings().ignoredProviders)) ?? []
            updatePlannedWeeks()
            dropMissingPlanned()
        }
    }

    private func trainerStrength(_ id: Int64) -> TrainerPlannedStrength? {
        guard id < 0 else { return nil }
        return trainerPlanned.first { $0.workout.id == id }
            ?? model.trainer.plannedStrength(from: Day.today(), days: WorkoutConstants.plannedDays).first { $0.workout.id == id }
    }

    private var plannedEnd: Day {
        WorkoutListModel.plannedEnd(today: Day.today(), mfitEnd: strengthProgram?.end, planEnd: model.trainer.strengthPlan?.end)
    }

    private var trainerPlannedKey: String {
        let sessions = model.trainer.strengthSessions.map { "\($0.id)\($0.group)\($0.minutes)\($0.place)" }.joined(separator: ",")
        return "\(Day.today().iso)|\(plannedEnd.iso)|\(sessions)"
    }

    private func refreshTrainerPlanned() {
        let today = Day.today()
        trainerPlanned = model.trainer.plannedStrength(from: today, days: today.days(until: plannedEnd))
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

    private func openLinkedWorkout() {
        guard case .workout(let id) = DeepLinkCenter.shared.take({ if case .workout = $0 { true } else { false } }) else { return }
        applyRestoration()
        path = [.activity(id)]
        selection = .activity(id)
    }

    private func applyStrength(_ cache: StrengthProgramCache, today: Day) {
        strengthProgram = cache.program
        let end = WorkoutListModel.plannedEnd(today: today, mfitEnd: cache.program?.end, planEnd: model.trainer.strengthPlan?.end)
        strengthPlanned = StrengthSchedule().workouts(cache.program, from: today, through: end)
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
            if let trainer = trainerStrength(id) {
                TrainerStrengthWorkoutView(iso: trainer.workout.day, sessionId: trainer.sessionId)
            } else {
                StrengthPlannedDetailView(workoutId: id)
            }
        }
    }

    private func list(_ weeks: [WorkoutWeek], hasRuns: Bool, visibility: PlannedVisibility, plannedItems: [WorkoutPlannedItem]) -> some View {
        let selected = current(weeks)
        let today = Day.today().iso
        return ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                DSScreenHeader(title: WorkoutConstants.listTitle) {
                    SyncStatusPill()
                }
                Picker(WorkoutCalendarConstants.modeNames[.calendar] ?? "", selection: $modeRaw) {
                    ForEach(WorkoutListMode.allCases) { Text(WorkoutCalendarConstants.modeNames[$0] ?? "").tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                if hasRuns {
                    WorkoutKindFilterBar(selection: $kindFilter)
                }
                if mode == .calendar {
                    calendarSection(weeks: weeks, plannedItems: plannedItems, visibility: visibility, selected: selected, today: today)
                } else {
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
                                CardDisclosure(expanded: showsPlanned)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        if showsPlanned {
                            ForEach(WorkoutListModel.plannedGroups(plannedItems)) { group in
                                Text(WorkoutListModel.weekLabel(group.start))
                                    .font(.caption)
                                    .foregroundStyle(BrandColors.dim)
                                    .padding(.top, 4)
                                ForEach(group.items) { item in plannedRow(item, today: today, selected: selected) }
                            }
                        } else {
                            ForEach(plannedItems.filter { $0.day == today }) { item in
                                plannedRow(item, today: today, selected: selected)
                            }
                        }
                    }
                    if weeks.isEmpty && model.showsSkeleton {
                        FirstSyncView()
                    } else if weeks.isEmpty && hasRuns {
                        DSEmptyState(symbol: "line.3.horizontal.decrease", title: WorkoutConstants.emptyFilter, text: WorkoutConstants.emptyFilterText)
                            .brandCard()
                    } else if weeks.isEmpty {
                        DSEmptyState(symbol: "figure.run", title: WorkoutConstants.emptyList, text: WorkoutConstants.emptyListText)
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
                        if model.isRefreshing && week.start == Day.today().weekStart {
                            SkeletonCards(heights: [SkeletonConstants.workoutRowHeight])
                        }
                        ForEach(week.rows) { row in
                            link(.activity(row.activityId)) {
                                WorkoutRow(row: row, isSelected: isSplit && selected == .activity(row.activityId), hasChat: (chatCounts[row.activityId] ?? 0) > 0, isFromPlan: visibility.fromPlanIds.contains(row.activityId), isNew: model.newActivityIds.contains(row.activityId))
                            }
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
    private func calendarSection(weeks: [WorkoutWeek], plannedItems: [WorkoutPlannedItem], visibility: PlannedVisibility, selected: WorkoutSelection?, today: String) -> some View {
        let rows = weeks.flatMap(\.rows)
        let range = WorkoutCalendarModel.plannedRange(month: calendarMonth, today: Day.today())
        let mfitMonth = range.map { StrengthSchedule().workouts(strengthProgram, from: $0.lowerBound, through: $0.upperBound) } ?? []
        let trainerMonth = range.map { month in
            trainerPlanned.map(\.workout).filter { Day(iso: $0.day).map(month.contains) ?? false }
        } ?? []
        let runs = plannedItems.filter { if case .run = $0 { return true } else { return false } }
        let strengthItems = WorkoutListModel.plannedItems(runs: [], strength: mfitMonth + trainerMonth, doneStrengthDays: strengthDoneDays.union(rows.filter(\.isStrength).map(\.dayIso)), filter: kindFilter)
        let calendarPlanned = runs + strengthItems
        let mfitIds = Set(mfitMonth.map(WorkoutCalendarModel.key))
        let days = WorkoutCalendarModel.days(rows: rows, planned: calendarPlanned, mfitIds: mfitIds)
        let dayRows = rows.filter { $0.dayIso == calendarDay.iso }
        let dayPlanned = calendarPlanned.filter { $0.day == calendarDay.iso }
        let summary = WorkoutCalendarModel.summary(rows: rows, month: calendarMonth)
        WorkoutCalendarView(month: $calendarMonth, selected: $calendarDay, days: days, today: Day.today())
            .onChange(of: calendarMonth) { _, month in
                calendarDay = WorkoutCalendarModel.defaultSelection(month: month, today: Day.today())
            }
        DSSectionTitle(WorkoutCalendarModel.dayTitle(calendarDay))
        if dayRows.isEmpty && dayPlanned.isEmpty {
            Text(WorkoutCalendarConstants.emptyDay).font(.footnote).foregroundStyle(BrandColors.dim).frame(maxWidth: .infinity, alignment: .leading).brandCard()
        }
        ForEach(dayPlanned) { item in plannedRow(item, today: today, selected: selected) }
        ForEach(dayRows) { row in
            link(.activity(row.activityId)) {
                WorkoutRow(row: row, isSelected: isSplit && selected == .activity(row.activityId), hasChat: (chatCounts[row.activityId] ?? 0) > 0, isFromPlan: visibility.fromPlanIds.contains(row.activityId), isNew: model.newActivityIds.contains(row.activityId))
            }
        }
        DSSectionTitle(WorkoutCalendarConstants.monthLabel)
        VStack(spacing: DSSpacing.s2) {
            HStack {
                Text(WorkoutCalendarConstants.runLabel).foregroundStyle(BrandColors.dim)
                Spacer()
                Text(String(format: WorkoutCalendarConstants.runSummaryFormat, WorkoutFormat.kilometers(summary.kilometers * WorkoutConstants.metersPerKilometer), summary.runs)).fontWeight(.semibold)
            }
            HStack {
                Text(WorkoutCalendarConstants.strengthLabel).foregroundStyle(BrandColors.dim)
                Spacer()
                Text(String(format: WorkoutCalendarConstants.strengthSummaryFormat, summary.strength)).fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        .brandCard()
    }

    @ViewBuilder
    private func plannedRow(_ item: WorkoutPlannedItem, today: String, selected: WorkoutSelection?) -> some View {
        switch item {
        case .run(let plan):
            link(.planned(plan.id)) {
                PlannedWorkoutRow(plan: plan, isToday: plan.day == today, isSelected: selected == .planned(plan.id), fallback: model.trainer.easyPaceBand)
            }
        case .strength(let workout):
            link(.strength(workout.id)) {
                StrengthPlannedRow(workout: workout, isToday: workout.day == today, isSelected: selected == .strength(workout.id))
            }
        }
    }

    private func weekBar(_ progress: Double) -> some View {
        DSProgressBar(value: progress, height: WorkoutConstants.weekBarHeight)
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
                .buttonStyle(.cardLink)
        } else {
            NavigationLink(value: item) { label() }
                .buttonStyle(.cardLink)
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
