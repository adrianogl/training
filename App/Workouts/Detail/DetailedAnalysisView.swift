import SwiftData
import SwiftUI

struct DetailedAnalysisView: View {
    let activityId: Int64
    let goalEntries: [WorkoutGoalEntry]
    @Environment(\.modelContext) private var context
    @State private var model: DetailedAnalysisModel?

    private typealias C = DetailedScreenConstants

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
                if let model {
                    content(model)
                } else {
                    writing
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
            section(C.kmTitle)
            DetailedKilometerChart(analysis: analysis)
            if !model.bars.isEmpty {
                section(C.similarTitle)
                DetailedSimilarChart(bars: model.bars)
            }
            if !analysis.findings.isEmpty {
                section(C.findingsTitle)
                DetailedFindingsCard(findings: analysis.findings)
            }
            if !analysis.recommendations.isEmpty {
                section(C.recommendationsTitle)
                DetailedRecommendationsCard(recommendations: analysis.recommendations)
            }
            if !model.sections.isEmpty {
                section(C.coachTitle)
                DetailedCoachCard(sections: model.sections, states: model.states)
            }
            if let sources = model.sourcesText {
                Text(sources).font(.caption2).foregroundStyle(BrandColors.dim)
            }
        } else if model.isLoaded {
            Text(C.unavailable).font(.subheadline).foregroundStyle(BrandColors.dim).padding(.top, 16)
        }
    }

    private var writing: some View {
        VStack(spacing: 16) {
            BrandLoader(size: .large)
                .padding(BrandLoaderConstants.large.ringGap)
            Text(C.writingTitle).font(.headline).foregroundStyle(BrandColors.text)
            Text(C.writingDetail)
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FirstSyncConstants.verticalPadding)
    }

    private func header(_ model: DetailedAnalysisModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandColors.text)
            Text(model.comparedText)
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
            if !model.tiles.isEmpty {
                Divider().overlay(BrandColors.line).padding(.vertical, 8)
                DetailedKPIRow(tiles: model.tiles)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .padding(.top, 12)
    }

    private func section(_ title: String) -> some View {
        DSSectionTitle(title)
            .padding(.top, DSSpacing.sectionTop - TodayConstants.rowSpacing)
            .padding(.bottom, DSSpacing.sectionBottom - TodayConstants.rowSpacing)
    }
}
