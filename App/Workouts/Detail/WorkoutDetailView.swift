import GarminAPI
import SwiftData
import SwiftUI
import TrainingCore

struct WorkoutDetailView: View {
    let activityId: Int64
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: WorkoutDetailModel?
    @State private var showsShare = false
    @State private var planCheck: PlannedBriefing?
    @State private var goalEntries: [WorkoutGoalEntry] = []
    @State private var showsChat = false
    @State private var stravaSending = false
    @State private var stravaFeedback: String?
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
            let loaded = WorkoutDetailModel(activityId: activityId, context: context)
            model = loaded
            goalEntries = WorkoutGoalCheck.entries(activityId: activityId, blocks: loaded.blocks, context: context)
            planCheck = await loadPlanCheck()
        }
        .alert(StravaConstants.sectionTitle, isPresented: Binding(get: { stravaFeedback != nil }, set: { if !$0 { stravaFeedback = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(stravaFeedback ?? "")
        }
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
                SummaryHeader(summary: summary)
                runSections(model)
            } else {
                SimpleWorkoutDetail(summary: summary, zoneShares: model.zoneShares)
            }
        } else {
            Text("Treino não encontrado.")
                .foregroundStyle(BrandColors.dim)
        }
    }

    @ViewBuilder
    private func runSections(_ model: WorkoutDetailModel) -> some View {
        VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
            DetailSectionHeader(WorkoutDetailConstants.sectionHowItWent)
            howItWent(model)
            if !goalEntries.isEmpty {
                WorkoutGoalCard(entries: goalEntries)
            }
            if hasWorkoutSection(model) {
                DetailSectionHeader(WorkoutDetailConstants.sectionWorkout)
            }
            if model.structureMissing {
                notice
            }
            if !model.blocks.isEmpty {
                labelled(model.hasPrescription ? "Blocos × prescrito" : "Parciais") {
                    BlocksSection(blocks: model.blocks, bars: model.bars, kilometers: model.kilometers, kilometerBars: model.kilometerBars, showsTarget: model.hasPrescription)
                }
                .id(WorkoutDetailSection.blocks)
            }
            pair {
                if !model.heartRate.isEmpty {
                    labelled("Frequência cardíaca") {
                        HeartRateChart(series: model.heartRate, bands: model.zoneBands, spans: model.activeSpans)
                    }
                    .id(WorkoutDetailSection.heartRate)
                }
                if model.ruler != nil || !model.zoneShares.isEmpty || model.weather != nil {
                    VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
                        if let ruler = model.ruler {
                            labelled("Tempo em zona de FC") { ZoneRuler(data: ruler) }
                                .id(WorkoutDetailSection.zones)
                        } else if !model.zoneShares.isEmpty {
                            labelled("Tempo em zona de FC") { ZonesBar(shares: model.zoneShares) }
                                .id(WorkoutDetailSection.zones)
                        }
                        if let weather = model.weather {
                            labelled(WorkoutDetailConstants.weatherTitle) { RunWeatherBand(effect: weather) }
                        }
                    }
                }
            }
            if !model.route.isEmpty {
                labelled("Percurso") {
                    RouteMapView(route: model.route, altitude: model.altitude)
                }
                .id(WorkoutDetailSection.route)
            }
            if model.comparison != nil, !model.comparisonRows.isEmpty {
                DetailSectionHeader(WorkoutDetailConstants.sectionComparison)
                labelled("Comparado com treinos parecidos") {
                    ComparisonSection(
                        title: model.comparisonTitle,
                        rows: model.comparisonRows,
                        evolution: model.evolutionText,
                        evolutionOnDevice: model.reading.evolutionOnDevice,
                        notice: model.comparisonNotice,
                        showsTarget: model.hasPrescription
                    )
                }
                .id(WorkoutDetailSection.comparison)
            }
            if model.chatContext != nil {
                chatButton
                    .padding(.top, 8)
            }
        }
    }

    private func howItWent(_ model: WorkoutDetailModel) -> some View {
        let showsScore = model.score != nil && !model.scoreRows.isEmpty
        let comparison = planCheck.flatMap { $0.comparison.isEmpty ? nil : $0 }
        return VStack(alignment: .leading, spacing: 16) {
            if showsScore || model.trainingEffect != nil {
                pair {
                    if let score = model.score, showsScore {
                        ScoreSummaryCard(value: score.value, rows: model.scoreRows, activityId: activityId, perfectLine: model.perfectLine, framed: false)
                    }
                    if let effect = model.trainingEffect {
                        TrainingEffectCard(effect: effect, framed: false)
                    }
                }
                Divider().overlay(BrandColors.line)
            }
            if let comparison {
                PlanComparisonCard(rows: comparison.comparison, note: comparison.comparisonNote, framed: false)
                Divider().overlay(BrandColors.line)
            }
            WorkoutAnalysisCard(summary: model.analysisSummary, activityId: activityId, goalEntries: goalEntries, aboveExpected: model.aboveExpected, framed: false)
        }
        .brandCard()
    }

    private func hasWorkoutSection(_ model: WorkoutDetailModel) -> Bool {
        model.structureMissing || !model.blocks.isEmpty || !model.heartRate.isEmpty || model.ruler != nil
            || !model.zoneShares.isEmpty || !model.route.isEmpty
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
        } label: {
            Image(systemName: WorkoutDetailConstants.actionsSymbol)
        }
        .accessibilityLabel(WorkoutDetailConstants.actionsTitle)
    }

    @ViewBuilder
    private func pair<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if sizeClass == .regular {
            ProportionalHStack(weights: WorkoutDetailConstants.pairWeights, spacing: TodayConstants.rowSpacing) { content() }
        } else {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) { content() }
        }
    }

    private func labelled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title).padding(.top, 0).padding(.bottom, 0)
            content()
        }
    }

    private func loadPlanCheck() async -> PlannedBriefing? {
        guard let model, model.hasPrescription, let iso = model.localDay, let day = Day(iso: iso),
              let done = model.completedCheck, let client = app.garminAccount.client,
              let plan = (try? await PlannedWorkouts.fetch(client: client, from: day, through: day))?.first else { return nil }
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

    private var notice: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Estrutura do treino ainda não baixada")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.attention)
            Text("Os blocos abaixo são os quilômetros do registro. A próxima sincronização baixa a estrutura e refaz a leitura.")
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
        }
        .brandCard()
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
