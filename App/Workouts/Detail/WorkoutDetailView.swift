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
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let model {
                        content(model)
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.bottom, 32)
            }
            .onChange(of: model == nil) { _, isLoading in
                guard !isLoading else { return }
                showsShare = model?.shareSource != nil && Self.debugOpensShare()
                guard let anchor = Self.debugScrollAnchor() else { return }
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: activityId) {
            model = WorkoutDetailModel(activityId: activityId, context: context)
            planCheck = await loadPlanCheck()
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
                SummaryHeader(summary: summary, onShare: model.shareSource == nil ? nil : { showsShare = true })
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
            if model.structureMissing {
                notice
            }
            pair {
                if let score = model.score, !model.scoreRows.isEmpty {
                    ScoreSummaryCard(value: score.value, rows: model.scoreRows)
                }
                if let effect = model.trainingEffect {
                    TrainingEffectCard(effect: effect)
                }
            }
            if let planCheck, !planCheck.comparison.isEmpty {
                PlanComparisonCard(rows: planCheck.comparison, note: planCheck.comparisonNote)
            }
            WorkoutAnalysisCard(summary: model.analysisSummary)
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
                if !model.route.isEmpty {
                    labelled("Percurso") {
                        RouteMapView(route: model.route, altitude: model.altitude)
                    }
                    .id(WorkoutDetailSection.route)
                }
            }
            pair {
                if let ruler = model.ruler {
                    labelled("Tempo em zona de FC") { ZoneRuler(data: ruler) }
                        .id(WorkoutDetailSection.zones)
                } else if !model.zoneShares.isEmpty {
                    labelled("Tempo em zona de FC") { ZonesBar(shares: model.zoneShares) }
                        .id(WorkoutDetailSection.zones)
                }
                if model.comparison != nil, !model.comparisonRows.isEmpty {
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
            }
        }
        .padding(.top, 12)
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
            daysSinceHard: input.daysSinceHard, race: input.race, weather: [], course: nil, completed: done
        ))
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
        .padding(.top, 16)
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
