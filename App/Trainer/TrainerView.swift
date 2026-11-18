import Insights
import SwiftUI
import TrainingCore

struct TrainerView: View {
    @Environment(AppModel.self) private var app
    @State private var showsNewPlan = false
    @State private var showsRequest = false
    @State private var showsEdit = false
    @State private var showsChat = false
    @State private var confirmsDelete = false
    @State private var confirmsEnd = false
    @State private var toggledWeeks: Set<String> = []
    @State private var highlightedWeek: String?
    @State private var tab: TrainerTab = .plan
    @State private var showsAdjustments = false
    @State private var showsSend = false
    @AppStorage(TrainerMFITConstants.keptDefaultsKey, store: AccountScope.current.defaults) private var keptSwaps = ""

    private var model: TrainerModel { app.trainer }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    CompactLogoHeader()
                    Text(TrainerText.title).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                    if let plan = model.plan {
                        shortcuts(proxy)
                        planContent(plan, proxy: proxy)
                    } else if model.isLoaded {
                        noPlanStrength
                        emptyState
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.plan != nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(TrainerText.editPlanMenu) { showsEdit = true }
                        if !model.cycleEnded {
                            Button(TrainerCycleText.endMenu) { confirmsEnd = true }
                        }
                        Button(TrainerText.deleteMenu, role: .destructive) { confirmsDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(TrainerText.deleteTitle, isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button(TrainerText.deleteConfirm, role: .destructive) { model.deletePlan() }
            Button(TrainerText.cancel, role: .cancel) {}
        } message: {
            Text(TrainerText.deleteMessage)
        }
        .confirmationDialog(TrainerCycleText.endTitle, isPresented: $confirmsEnd, titleVisibility: .visible) {
            Button(TrainerCycleText.endConfirm, role: .destructive) { Task { await model.endCycle() } }
            Button(TrainerText.cancel, role: .cancel) {}
        } message: {
            Text(TrainerCycleText.endMessage(weeks: model.finishedWeekCount))
        }
        .navigationDestination(for: TrainerRoute.self) { route in
            switch route {
            case .day(let iso): TrainerDayView(iso: iso)
            case .changes: TrainerChangesView()
            case .strength: TrainerStrengthView()
            case .cycle: TrainerCycleView()
            case .strengthDay(let iso, let id): TrainerStrengthWorkoutView(iso: iso, sessionId: id)
            }
        }
        .sheet(isPresented: $showsNewPlan) { TrainerNewPlanView() }
        .sheet(isPresented: $showsRequest) { TrainerRequestView() }
        .sheet(isPresented: $showsChat) { TrainerChatSheet() }
        .sheet(isPresented: $showsEdit) { TrainerNewPlanView(isEditing: true) }
        .sheet(isPresented: $showsSend) { TrainerSendSheet() }
        .task(id: autoSendKey) {
            let client = app.garminAccount.client
            Task { await model.autoSend(client: client) }
        }
        .task { await model.load() }
        .task(id: app.garminAccount.isSignedIn) {
            await model.loadExternal(client: app.garminAccount.client)
        }
        .task(id: app.mfitAccount.revision) {
            guard app.mfitAccount.isSignedIn else { return }
            await model.syncStrength(TrainerMFITStrength.sessions(program: StrengthProgramStore().load().program, schedule: StrengthSchedule()))
        }
    }

    private var autoSendKey: String {
        let plan = model.plan
        return [String(plan?.versions.count ?? 0), String(plan?.strength.count ?? 0), model.currentDay.iso, String(app.garminAccount.isSignedIn)].joined(separator: "|")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TrainerStrengthText.runPlanTitle).font(.headline).foregroundStyle(BrandColors.text)
            Text(TrainerStrengthText.runPlanBody).font(.footnote).foregroundStyle(BrandColors.dim)
            Button(TrainerStrengthText.createRunPlan) { showsNewPlan = true }
                .buttonStyle(.ds(.secondary))
        }
        .brandCard()
    }

    private var noPlanStrength: some View {
        let sessions = model.strengthSessions.sorted { $0.weekday < $1.weekday }
        let mfitDays = sessions.filter { $0.source == .mfit }.map { TrainerText.weekdayName($0.weekday - 1) }
        return VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(TrainerStrengthText.weekTitle)
            ForEach(sessions.filter { $0.source == .trainer }) { session in
                HStack(spacing: 10) {
                    Text(TrainerText.weekdayName(session.weekday - 1)).font(.caption.weight(.bold)).foregroundStyle(BrandColors.text)
                        .frame(width: TrainerConstants.dayDateWidth, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(TrainerStrengthText.focusName(session.group)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        Text(TrainerStrengthText.caption(session)).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    Spacer(minLength: 6)
                    TrainerStrengthSourceChip(source: .trainer)
                }
            }
            if !mfitDays.isEmpty {
                Text(String(format: TrainerStrengthText.mfitDaysFormat, mfitDays.joined(separator: ", "))).font(.caption).foregroundStyle(BrandColors.dim)
            }
            if sessions.isEmpty {
                Text(TrainerText.strengthCardEmpty).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            NavigationLink(value: TrainerRoute.strength) { Text(TrainerStrengthText.openStrength) }
                .buttonStyle(.ds(.primary))
        }
        .brandCard()
    }

    private func shortcuts(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                NavigationLink(value: TrainerRoute.strength) { shortcutLabel(TrainerStrengthText.shortcutStrength, symbol: "dumbbell") }
                    .buttonStyle(.plain)
                Button { showsSend = true } label: { shortcutLabel(TrainerStrengthText.shortcutSend, symbol: "applewatch") }
                    .buttonStyle(.plain)
                Button {
                    withAnimation { showsAdjustments = true }
                    Task {
                        try? await Task.sleep(for: .seconds(TrainerConstants.tabSwitchSeconds))
                        withAnimation { proxy.scrollTo(TrainerConstants.adjustmentsAnchor, anchor: .top) }
                    }
                } label: { shortcutLabel(TrainerStrengthText.shortcutAdjustments, symbol: "slider.horizontal.3") }
                    .buttonStyle(.plain)
            }
        }
    }

    private func shortcutLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(BrandColors.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(BrandColors.track, in: Capsule())
    }

    @ViewBuilder
    private func planContent(_ plan: TrainerPlan, proxy: ScrollViewProxy) -> some View {
        if let swap = model.legSwapSuggestion(kept: Set(keptSwaps.split(separator: ",").map(String.init))) {
            TrainerLegSwapCard(swap: swap) {
                model.applyLegSwap(swap)
            } onKeep: {
                keptSwaps = (keptSwaps.split(separator: ",").map(String.init) + [swap.quality.day.iso]).joined(separator: ",")
            }
        }
        if model.showsCycleBanner, let review = model.cycleReview {
            cycleBanner(review, dated: plan.target.date != nil)
        }
        if model.hasUnseenVersion, let version = model.latestVersion {
            updatedBanner(version)
        }
        let ended = model.cycleEnded
        TrainerPlanHeaderCard(
            plan: plan, boards: model.scoreboards, cells: model.weekCells, weeksToTarget: model.weeksToTarget,
            weekProgress: TrainerText.weekProgress(index: model.currentWeekIndex, total: plan.weeks.count),
            onToggleLight: { start in Task { await model.toggleLightWeek(start) } },
            onSelect: { start in select(start, proxy: proxy) },
            cycle: ended ? model.cycleReview : nil
        )
        if ended {
            endedActions
        } else {
            activeContent(plan)
        }
        previousCycles
    }

    @ViewBuilder
    private func activeContent(_ plan: TrainerPlan) -> some View {
        let compareWeeks = model.compareWeeks
        if !compareWeeks.isEmpty {
            TrainerTabPicker(tab: $tab)
        }
        if tab == .compare && !compareWeeks.isEmpty {
            TrainerCompareView(weeks: compareWeeks, weekIndex: { model.weekIndex(of: $0.start) })
        } else {
            planBody(plan)
                .syncSkeleton(model.isAdjusting, height: SkeletonConstants.trainerWeekHeight)
        }
    }

    @ViewBuilder
    private var endedActions: some View {
        if model.cycleReview != nil {
            NavigationLink(value: TrainerRoute.cycle) { Text(TrainerCycleText.openAnalysis) }
                .buttonStyle(.ds(.primary))
                .padding(.top, 4)
        }
        Button(TrainerText.newPlanTitle) { showsNewPlan = true }
            .buttonStyle(.ds(.secondary))
    }

    @ViewBuilder
    private var previousCycles: some View {
        if !model.cycleSummaries.isEmpty {
            DSSectionTitle(TrainerCycleText.previousTitle).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
            ForEach(model.cycleSummaries) { TrainerCycleSummaryRow(summary: $0) }
        }
    }

    private func cycleBanner(_ review: TrainerCycleReview, dated: Bool) -> some View {
        NavigationLink(value: TrainerRoute.cycle) { TrainerCycleBanner(review: review, dated: dated) }
            .buttonStyle(.cardLink)
    }

    private func updatedBanner(_ version: TrainerVersion) -> some View {
        NavigationLink(value: TrainerRoute.changes) {
            DSNotice(tone: .success, title: TrainerText.updatedBanner, text: TrainerText.triggerText(version), trailing: CardLinkBadge())
        }
        .buttonStyle(.cardLink)
    }

    @ViewBuilder
    private func planBody(_ plan: TrainerPlan) -> some View {
        DSSectionTitle(TrainerText.upcoming).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
        ForEach(model.weekGroups) { group in
            weekSection(group)
        }
        Button { showsSend = true } label: {
            Label(TrainerSendText.openButton, systemImage: "applewatch")
        }
        .buttonStyle(.ds(.primary))
        .padding(.top, 4)
        adjustments(plan)
        AskIntelligenceButton(title: TrainerChatConstants.ask) { showsChat = true }
        if model.saveFailed {
            Text(TrainerText.saveError).font(.footnote).foregroundStyle(BrandColors.danger)
        }
    }

    @ViewBuilder
    private func adjustments(_ plan: TrainerPlan) -> some View {
        Button { withAnimation { showsAdjustments.toggle() } } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TrainerText.adjustmentsTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Text(TrainerText.adjustmentsSummary(strength: plan.strength, longMode: plan.longMode))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
                Spacer(minLength: 6)
                CardDisclosure(expanded: showsAdjustments)
            }
            .brandCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .id(TrainerConstants.adjustmentsAnchor)
        if showsAdjustments {
            strengthCard(plan)
            TrainerLongModeCard(mode: plan.longMode, suggestion: model.longSuggestion) { mode in
                Task { await model.setLongMode(mode) }
            }
            Button { showsEdit = true } label: {
                Label(TrainerText.editPacesButton, systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.ds(.secondary))
            Button { showsRequest = true } label: {
                Label(TrainerText.askButton, systemImage: "square.and.pencil")
            }
            .buttonStyle(.ds(.secondary))
        }
    }

    private func select(_ start: Day, proxy: ScrollViewProxy) {
        guard tab != .plan else { return reveal(start, proxy: proxy) }
        tab = .plan
        Task {
            try? await Task.sleep(for: .seconds(TrainerConstants.tabSwitchSeconds))
            reveal(start, proxy: proxy)
        }
    }

    private func isOpen(_ group: TrainerWeekGroup) -> Bool {
        let nextStart = model.currentDay.weekStart.adding(days: TrainerConstants.weekdayCount * TrainerConstants.expandedFutureWeeks)
        let byDefault = group.isCurrent || group.start == nextStart
        return byDefault != toggledWeeks.contains(group.id)
    }

    private func setOpen(_ group: TrainerWeekGroup, _ open: Bool) {
        if isOpen(group) != open {
            if toggledWeeks.contains(group.id) { toggledWeeks.remove(group.id) } else { toggledWeeks.insert(group.id) }
        }
    }

    private func reveal(_ start: Day, proxy: ScrollViewProxy) {
        guard let group = model.weekGroups.first(where: { $0.start == start }) else { return }
        setOpen(group, true)
        withAnimation { proxy.scrollTo(group.id, anchor: .top) }
        highlightedWeek = group.id
        Task {
            try? await Task.sleep(for: .seconds(TrainerConstants.highlightSeconds))
            withAnimation { highlightedWeek = nil }
        }
    }

    private func weekSection(_ group: TrainerWeekGroup) -> some View {
        let open = isOpen(group)
        return VStack(alignment: .leading, spacing: 6) {
            Button { setOpen(group, !open) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(group.title).font(.caption.weight(.medium)).tracking(1).textCase(.uppercase).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(group.caption).font(.caption).foregroundStyle(BrandColors.dim)
                    CardDisclosure(expanded: open)
                }
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(model.isLightWeek(group.start) ? TrainerText.unmarkLight : TrainerText.markLight) {
                    Task { await model.toggleLightWeek(group.start) }
                }
            }
            if open {
                ForEach(group.rows) { row in
                    NavigationLink(value: TrainerRoute.day(row.id)) {
                        TrainerDayRowView(row: row, isToday: row.workout.day == model.currentDay)
                    }
                    .buttonStyle(.cardLink)
                }
            }
        }
        .padding(6)
        .background(highlightedWeek == group.id ? BrandColors.accentGlow : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(group.isPast ? 0.7 : 1)
        .id(group.id)
    }

    private func strengthCard(_ plan: TrainerPlan) -> some View {
        NavigationLink(value: TrainerRoute.strength) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TrainerText.strengthTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Text(plan.strength.isEmpty ? TrainerText.strengthCardEmpty : TrainerText.strengthSummary(plan.strength))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
                Spacer(minLength: 6)
                CardLinkBadge()
            }
            .brandCard()
        }
        .buttonStyle(.cardLink)
    }
}

