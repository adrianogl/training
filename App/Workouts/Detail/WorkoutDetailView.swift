import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    let activityId: Int64
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: WorkoutDetailModel?
    @State private var showsShare = false

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
                showsShare = model?.shareInput != nil && Self.debugOpensShare()
                guard let anchor = Self.debugScrollAnchor() else { return }
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: activityId) {
            model = WorkoutDetailModel(activityId: activityId, context: context)
        }
        .sheet(isPresented: $showsShare) {
            if let input = model?.shareInput {
                ShareEditorView(input: input)
            }
        }
    }

    @ViewBuilder
    private func content(_ model: WorkoutDetailModel) -> some View {
        if let summary = model.summary {
            if model.isRun {
                SummaryHeader(summary: summary, onShare: model.shareInput == nil ? nil : { showsShare = true })
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
            AnalysisCard(columns: model.analysisColumns, onDevice: model.reading.findingsOnDevice)
            if !model.blocks.isEmpty {
                labelled(model.hasPrescription ? "Blocos × prescrito" : "Parciais") {
                    BlocksSection(blocks: model.blocks, bars: model.bars, kilometers: model.kilometers, kilometerBars: model.kilometerBars, showsTarget: model.hasPrescription, markers: model.analysisColumns.blockMarkers)
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
