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

    private var model: TrainerModel { app.trainer }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(TrainerText.title).font(.largeTitle.weight(.bold)).foregroundStyle(BrandColors.text)
                        TrainerBetaBadge()
                    }
                    if let plan = model.plan {
                        planContent(plan, proxy: proxy)
                    } else if model.isLoaded {
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
            }
        }
        .sheet(isPresented: $showsNewPlan) { TrainerNewPlanView() }
        .sheet(isPresented: $showsRequest) { TrainerRequestView() }
        .sheet(isPresented: $showsChat) { TrainerChatSheet() }
        .sheet(isPresented: $showsEdit) { TrainerNewPlanView(isEditing: true) }
        .task { await model.load() }
        .task(id: app.garminAccount.isSignedIn) {
            await model.loadExternal(client: app.garminAccount.client)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TrainerText.emptyTitle).font(.headline).foregroundStyle(BrandColors.text)
            Text(TrainerText.emptyBody).font(.footnote).foregroundStyle(BrandColors.dim)
            Button(TrainerText.cardCreate) { showsNewPlan = true }
                .buttonStyle(TrainerPrimaryButtonStyle())
        }
        .brandCard()
    }

    @ViewBuilder
    private func planContent(_ plan: TrainerPlan, proxy: ScrollViewProxy) -> some View {
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
        }
    }

    @ViewBuilder
    private var endedActions: some View {
        if model.cycleReview != nil {
            NavigationLink(value: TrainerRoute.cycle) { Text(TrainerCycleText.openAnalysis) }
                .buttonStyle(TrainerPrimaryButtonStyle())
                .padding(.top, 4)
        }
        Button(TrainerText.newPlanTitle) { showsNewPlan = true }
            .buttonStyle(TrainerSecondaryButtonStyle())
    }

    @ViewBuilder
    private var previousCycles: some View {
        if !model.cycleSummaries.isEmpty {
            SectionHeader(TrainerCycleText.previousTitle)
            ForEach(model.cycleSummaries) { TrainerCycleSummaryRow(summary: $0) }
        }
    }

    private func cycleBanner(_ review: TrainerCycleReview, dated: Bool) -> some View {
        NavigationLink(value: TrainerRoute.cycle) { TrainerCycleBanner(review: review, dated: dated) }
            .buttonStyle(.plain)
    }

    private func updatedBanner(_ version: TrainerVersion) -> some View {
        NavigationLink(value: TrainerRoute.changes) {
            HStack(spacing: 8) {
                Text("⟳").foregroundStyle(BrandColors.accent)
                (Text(TrainerText.updatedBanner).fontWeight(.bold).foregroundStyle(BrandColors.accent)
                    + Text(" \(TrainerText.triggerText(version))").foregroundStyle(BrandColors.text))
                    .font(.footnote)
                Spacer(minLength: 6)
                Text(TrainerText.updatedAction).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(BrandColors.accentGlow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BrandColors.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func planBody(_ plan: TrainerPlan) -> some View {
        SectionHeader(TrainerText.upcoming)
        ForEach(model.weekGroups) { group in
            weekSection(group)
        }
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
                Image(systemName: showsAdjustments ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(BrandColors.dim)
            }
            .brandCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        if showsAdjustments {
            strengthCard(plan)
            TrainerLongModeCard(mode: plan.longMode, suggestion: model.longSuggestion) { mode in
                Task { await model.setLongMode(mode) }
            }
            Button { showsEdit = true } label: {
                Label(TrainerText.editPacesButton, systemImage: "slider.horizontal.3")
            }
            .buttonStyle(TrainerSecondaryButtonStyle())
            Button { showsRequest = true } label: {
                Label(TrainerText.askButton, systemImage: "square.and.pencil")
            }
            .buttonStyle(TrainerSecondaryButtonStyle())
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
                    Image(systemName: open ? "chevron.down" : "chevron.right").font(.caption2).foregroundStyle(BrandColors.dim)
                    Text(group.title).font(.caption.weight(.medium)).tracking(1).textCase(.uppercase).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(group.caption).font(.caption).foregroundStyle(BrandColors.dim)
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
                    .buttonStyle(.plain)
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
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrandColors.dim)
            }
            .brandCard()
        }
        .buttonStyle(.plain)
    }
}

struct TrainerPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(BrandColors.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct TrainerSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(BrandColors.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(BrandColors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BrandColors.cardBorder, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
