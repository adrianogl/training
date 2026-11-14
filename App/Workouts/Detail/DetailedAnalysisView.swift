import SwiftData
import SwiftUI

struct DetailedAnalysisView: View {
    let activityId: Int64
    let goalEntries: [WorkoutGoalEntry]
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: DetailedAnalysisModel?

    private typealias C = DetailedScreenConstants

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
                if let model {
                    content(model)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 32)
        }
        .background(BrandBackground())
        .navigationTitle(C.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let loaded = DetailedAnalysisModel(activityId: activityId, goalEntries: goalEntries, context: context)
            model = loaded
            await loaded.generateCoach()
        }
    }

    @ViewBuilder
    private func content(_ model: DetailedAnalysisModel) -> some View {
        if let analysis = model.analysis {
            header(model)
            DetailedKPIRow(tiles: model.tiles)
            columns {
                DetailedKilometerChart(analysis: analysis)
                if !model.bars.isEmpty {
                    DetailedSimilarChart(bars: model.bars)
                }
            } trailing: {
                if !analysis.findings.isEmpty { DetailedFindingsCard(findings: analysis.findings) }
                if !analysis.recommendations.isEmpty { DetailedRecommendationsCard(recommendations: analysis.recommendations) }
            }
            if !model.sections.isEmpty {
                DetailedCoachCard(sections: model.sections, states: model.states)
            }
            if let sources = model.sourcesText {
                Text(sources).font(.caption2).foregroundStyle(BrandColors.dim)
            }
        } else if model.isLoaded {
            Text(C.unavailable).font(.subheadline).foregroundStyle(BrandColors.dim).padding(.top, 16)
        }
    }

    private func header(_ model: DetailedAnalysisModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.text)
            Text(model.comparedText)
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func columns<Leading: View, Trailing: View>(
        @ViewBuilder _ leading: () -> Leading, @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        if sizeClass == .regular {
            ProportionalHStack(weights: C.columnWeights, spacing: TodayConstants.rowSpacing) {
                VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) { leading() }
                VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) { trailing() }
            }
        } else {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
                leading()
                trailing()
            }
        }
    }
}
