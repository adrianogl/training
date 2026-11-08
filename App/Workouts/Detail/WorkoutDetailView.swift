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
            SummaryHeader(summary: summary)
        } else {
            Text("Treino não encontrado.")
                .foregroundStyle(BrandColors.dim)
        }
        if model.isRun {
            if model.structureMissing {
                notice
            }
            sectionLabel("Leitura")
            FindingsSection(assessment: model.assessment, blocks: model.blocks)
            if !model.blocks.isEmpty {
                sectionLabel(model.hasPrescription ? "Blocos × prescrito" : "Parciais")
                    .id(WorkoutDetailSection.blocks)
                BlocksSection(blocks: model.blocks, bars: model.bars, showsTarget: model.hasPrescription)
            }
            if let comparison = model.comparison, !model.comparisonRows.isEmpty {
                sectionLabel("Comparado com treinos parecidos")
                    .id(WorkoutDetailSection.comparison)
                ComparisonSection(
                    title: model.comparisonTitle,
                    rows: model.comparisonRows,
                    evolution: model.evolutionText,
                    sameStructure: comparison.sameStructure || !model.hasPrescription,
                    showsTarget: model.hasPrescription
                )
            }
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

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(BrandColors.dim)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .padding(.horizontal, 2)
    }

    private static func debugScrollAnchor(defaults: UserDefaults = .standard) -> WorkoutDetailSection? {
        #if DEBUG
        return defaults.string(forKey: AppConstants.detailScrollDefaultsKey).flatMap(WorkoutDetailSection.init(rawValue:))
        #else
        return nil
        #endif
    }
}
