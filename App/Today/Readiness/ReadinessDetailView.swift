import SwiftUI

struct ReadinessDetailView: View {
    let model: TodayModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                if let summaryText = model.readinessSummaryText {
                    Text(summaryText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                }
                if !model.readinessSentence.isEmpty {
                    Text(model.readinessSentence)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                }
                group(TodayConstants.detailUp, .up, BrandColors.accent)
                group(TodayConstants.detailDown, .down, BrandColors.attention)
                group(TodayConstants.detailNoBaseline, .baseline, BrandColors.dim)
                group(TodayConstants.detailMissing, .missing, BrandColors.dim)
                if let stress = model.readinessDay.stress {
                    Text("\(TodayConstants.supportStress) \(stress). \(TodayConstants.detailStressContext)")
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                        .padding(.top, 8)
                }
                SectionLabel(TodayConstants.detailExplanationTitle)
                Text(TodayConstants.detailExplanation)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.dim)
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 32)
        }
        .background(BrandBackground())
        .navigationTitle(TodayConstants.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var header: some View {
        if let breakdown = model.summary.readiness {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(breakdown.score)")
                    .font(BrandFonts.number(64))
                    .foregroundStyle(ReadinessRuler.color(for: breakdown.score))
                Text(model.summary.verdict.flatMap { TodayConstants.verdictPhrases[$0] } ?? "")
                    .font(.headline)
                    .foregroundStyle(BrandColors.text)
            }
            ReadinessRuler(score: breakdown.score, showsLabels: true)
        } else {
            Text(TodayConstants.readinessEmpty)
                .foregroundStyle(BrandColors.dim)
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ kind: ReadinessGroup, _ color: Color) -> some View {
        let rows = model.factorRows.filter { $0.group == kind }
        if !rows.isEmpty {
            Text(title)
                .font(.caption.weight(.medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(color)
                .padding(.top, 14)
            ForEach(rows) { ReadinessFactorRow(row: $0) }
        }
    }
}
