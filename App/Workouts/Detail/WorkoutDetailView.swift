import GarminAPI
import SwiftData
import SwiftUI
import TrainingCore

struct WorkoutDetailView: View {
    let activityId: Int64
    @Environment(\.modelContext) private var context
    @State private var model: WorkoutDetailModel?
    @State private var showsShare = false
    @State private var planCheck: PlannedBriefing?
    @State private var goalEntries: [WorkoutGoalEntry] = []
    @State private var showsChat = false
    @State private var stravaSending = false
    @State private var stravaFeedback: String?
    @State private var confirmsDelete = false
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let model {
                        content(model)
                    } else {
                        BrandLoader(size: .regular).frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.bottom, 32)
            }
            .onChange(of: model == nil) { _, isLoading in
                guard !isLoading else { return }
                showsShare = model?.shareSource != nil && Self.debugOpensShare()
                showsChat = model?.chatContext != nil && Self.debugChatQuestion() != nil
                guard let anchor = Self.debugScrollAnchor() else { return }
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model?.isRun == true, model?.shareSource != nil || app.strava.status.connected {
                ToolbarItem(placement: .topBarTrailing) { actionsMenu }
            }
        }
        .task(id: activityId) {
            await load()
        }
        .onChange(of: app.dataToken) {
            guard model?.scorePending != nil else { return }
            Task { await load() }
        }
        .alert(StravaConstants.sectionTitle, isPresented: Binding(get: { stravaFeedback != nil }, set: { if !$0 { stravaFeedback = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(stravaFeedback ?? "")
        }
        .activityDeletion(activityId, isPresented: $confirmsDelete)
        .sheet(isPresented: $showsChat) {
            if let context = model?.chatContext {
                WorkoutChatSheet(activityId: activityId, context: context, autoQuestion: Self.debugChatQuestion())
                    .presentationSizing(.page)
            }
        }
        .sheet(isPresented: $showsShare) {
            if let source = model?.shareSource {
                ShareStudioView(source: source)
                    .presentationSizing(.page)
            }
        }
    }

    @ViewBuilder
    private func content(_ model: WorkoutDetailModel) -> some View {
        if let summary = model.summary {
            if model.isRun {
                SummaryHeader(summary: summary, weather: model.weather)
                runSections(model)
            } else {
                SimpleWorkoutDetail(summary: summary, zoneShares: model.zoneShares)
            }
        } else {
            DSEmptyState(symbol: "figure.run", title: WorkoutDetailConstants.notFoundTitle, text: WorkoutDetailConstants.notFoundText)
        }
    }

    @ViewBuilder
    private func runSections(_ model: WorkoutDetailModel) -> some View {
        VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
            let C = WorkoutDetailConstants.self
            howItWent(model)
            if !model.recordHits.isEmpty {
                section(RecordText.section(model.recordHits.count))
                WorkoutRecordsCard(hits: model.recordHits, steps: model.recordSteps, activityId: activityId)
            }
            if !goalEntries.isEmpty {
                section(C.sectionGoal)
                WorkoutGoalCard(entries: goalEntries, showsLabel: false)
            }
            if !model.blocks.isEmpty || model.structureMissing {
                section(model.hasPrescription ? C.sectionBlocks : C.sectionSplits)
                    .id(WorkoutDetailSection.blocks)
            }
            if model.structureMissing {
                DSNotice(tone: .attention, title: C.structureMissingTitle, text: C.structureMissingText)
            }
            if !model.blocks.isEmpty {
                BlocksSection(blocks: model.blocks, bars: model.bars, kilometers: model.kilometers, kilometerBars: model.kilometerBars, showsTarget: model.hasPrescription)
            }
            if !model.heartRate.isEmpty {
                section(C.sectionHeartRate).id(WorkoutDetailSection.heartRate)
                HeartRateChart(series: model.heartRate, bands: model.zoneBands, spans: model.activeSpans)
            }
            if let ruler = model.ruler {
                section(C.sectionZones).id(WorkoutDetailSection.zones)
                ZoneRuler(data: ruler)
            } else if !model.zoneShares.isEmpty {
                section(C.sectionZones).id(WorkoutDetailSection.zones)
                ZonesBar(shares: model.zoneShares)
            }
            if !model.route.isEmpty {
                section(C.sectionRoute).id(WorkoutDetailSection.route)
                RouteMapView(route: model.route, altitude: model.altitude)
            }
            if model.comparison != nil, !model.comparisonRows.isEmpty {
                section(C.sectionComparison).id(WorkoutDetailSection.comparison)
                ComparisonSection(
                    title: C.comparisonHeader,
                    rows: model.comparisonRows,
                    evolution: model.evolutionText,
                    evolutionOnDevice: model.reading.evolutionOnDevice,
                    notice: model.comparisonNotice,
                    showsTarget: model.hasPrescription
                )
            }
            if model.chatContext != nil {
                chatButton
                    .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private func howItWent(_ model: WorkoutDetailModel) -> some View {
        let C = WorkoutDetailConstants.self
        if let pending = model.scorePending {
            section(C.sectionScore)
            ScoreLoadingCard(pending: pending, showsLabel: false)
        } else if let score = model.score, !model.scoreRows.isEmpty {
            section(C.sectionScore)
            ScoreSummaryCard(value: score.value, rows: model.scoreRows, activityId: activityId, perfectLine: model.perfectLine, showsLabel: false)
        }
        if let effect = model.trainingEffect {
            section(C.sectionEffect)
            TrainingEffectCard(effect: effect, showsLabel: false)
        }
        if let comparison = planCheck, !comparison.comparison.isEmpty {
            section(C.sectionPlan)
            PlanComparisonCard(rows: comparison.comparison, note: comparison.comparisonNote, showsLabel: false)
        }
        section(C.analysisTitle)
        WorkoutAnalysisCard(summary: model.analysisSummary, activityId: activityId, goalEntries: goalEntries, aboveExpected: model.aboveExpected, extraFacts: WorkoutCoachFacts.facts(model, goals: goalEntries, plan: planCheck), showsLabel: false)
    }

    private func load() async {
        let analysis = await WorkoutAnalysisStore.load(activityId: activityId, container: context.container)
        let loaded = WorkoutDetailModel(activityId: activityId, context: context, analysis: analysis)
        model = loaded
        goalEntries = WorkoutGoalCheck.entries(activityId: activityId, blocks: loaded.blocks, context: context)
        planCheck = await loadPlanCheck()
    }

    private func section(_ title: String) -> some View {
        DSSectionTitle(title)
            .padding(.top, DSSpacing.sectionTop - TodayConstants.rowSpacing)
            .padding(.bottom, DSSpacing.sectionBottom - TodayConstants.rowSpacing)
    }

    private var actionsMenu: some View {
        Menu {
            if model?.shareSource != nil {
                Button { showsShare = true } label: {
                    Label(WorkoutDetailConstants.shareTitle, systemImage: WorkoutDetailConstants.shareSymbol)
                }
            }
            if app.strava.status.connected {
                Button(app.strava.ledger.isSent(activityId) ? StravaConstants.resendButton : StravaConstants.sendButton, systemImage: "arrow.up.forward.app") {
                    Task {
                        stravaSending = true
                        stravaFeedback = await app.strava.send(activityId: activityId).message
                        stravaSending = false
                    }
                }
                .disabled(stravaSending)
            }
            Divider()
            ActivityDeleteButton(isPresented: $confirmsDelete)
        } label: {
            Image(systemName: WorkoutDetailConstants.actionsSymbol)
        }
        .accessibilityLabel(WorkoutDetailConstants.actionsTitle)
    }

    private func loadPlanCheck() async -> PlannedBriefing? {
        guard let model, model.hasPrescription, let iso = model.localDay, let day = Day(iso: iso),
              let done = model.completedCheck, let client = app.garminAccount.client,
              let plan = (try? await PlannedWorkouts.fetch(client: client, from: day, through: day, ignoring: TrainerSendStore().settings().ignoredProviders))?.first else { return nil }
        let input = PlannedBriefingLoader.input(plan: plan, week: [plan], context: context, today: day, weeklyGoalKm: 0, weather: [], course: nil)
        return PlannedBriefingBuilder.briefing(BriefingInput(
            plan: input.plan, today: input.today, similar: input.similar, readiness: input.readiness,
            weekDoneKm: input.weekDoneKm, weekPlannedKm: input.weekPlannedKm, weekGoalKm: input.weekGoalKm,
            daysSinceHard: input.daysSinceHard, race: input.race, weather: [], course: nil, completed: done, goals: input.goals
        ))
    }

    private var chatButton: some View {
        AskIntelligenceButton(title: WorkoutChatConstants.ask) { showsChat = true }
    }

    private static func debugChatQuestion(defaults: UserDefaults = .standard) -> String? {
        #if DEBUG
        return defaults.string(forKey: AppConstants.openChatDefaultsKey)
        #else
        return nil
        #endif
    }

    private static func debugOpensShare(defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return defaults.bool(forKey: AppConstants.openShareDefaultsKey)
        #else
        return false
        #endif
    }

    private static func debugScrollAnchor(defaults: UserDefaults = .standard) -> WorkoutDetailSection? {
        #if DEBUG
        return defaults.string(forKey: AppConstants.detailScrollDefaultsKey).flatMap(WorkoutDetailSection.init(rawValue:))
        #else
        return nil
        #endif
    }
}
