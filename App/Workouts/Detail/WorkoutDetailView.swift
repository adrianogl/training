import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    let activityId: Int64
    @Environment(\.modelContext) private var context
    @State private var model: WorkoutDetailModel?

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
                guard !isLoading, let anchor = Self.debugScrollAnchor() else { return }
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task(id: activityId) {
            model = WorkoutDetailModel(activityId: activityId, context: context)
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
        if model.structureMissing {
            notice
        }
        SectionLabel("Leitura")
        FindingsSection(assessment: model.assessment, blocks: model.blocks)
        if !model.blocks.isEmpty {
            SectionLabel(model.hasPrescription ? "Blocos × prescrito" : "Parciais")
                .id(WorkoutDetailSection.blocks)
            BlocksSection(blocks: model.blocks, bars: model.bars, showsTarget: model.hasPrescription)
        }
        if !model.route.isEmpty {
            SectionLabel("Percurso")
                .id(WorkoutDetailSection.route)
            RouteMapView(route: model.route, altitude: model.altitude)
        }
        if !model.heartRate.isEmpty {
            SectionLabel("Frequência cardíaca")
                .id(WorkoutDetailSection.heartRate)
            HeartRateChart(series: model.heartRate, bands: model.zoneBands, spans: model.activeSpans)
        }
        if !model.zoneShares.isEmpty {
            SectionLabel("Tempo em zona de FC")
                .id(WorkoutDetailSection.zones)
            ZonesBar(shares: model.zoneShares)
        }
        if model.comparison != nil, !model.comparisonRows.isEmpty {
            SectionLabel("Comparado com treinos parecidos")
                .id(WorkoutDetailSection.comparison)
            ComparisonSection(
                title: model.comparisonTitle,
                rows: model.comparisonRows,
                evolution: model.evolutionText,
                notice: model.comparisonNotice,
                showsTarget: model.hasPrescription
            )
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
        .glassCard()
        .padding(.top, 16)
    }

    private static func debugScrollAnchor(defaults: UserDefaults = .standard) -> WorkoutDetailSection? {
        #if DEBUG
        return defaults.string(forKey: AppConstants.detailScrollDefaultsKey).flatMap(WorkoutDetailSection.init(rawValue:))
        #else
        return nil
        #endif
    }
}
