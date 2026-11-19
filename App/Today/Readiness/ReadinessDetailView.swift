import Metrics
import SwiftUI

struct ReadinessDetailView: View {
    let model: TodayModel
    var recovery: RecoveryEstimate?

    private typealias C = TodayConstants

    var body: some View {
        ScrollView { content }
            .background(BrandBackground())
            .navigationTitle(C.detailTitle)
            .navigationBarTitleDisplayMode(.inline)
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
            if let overload = model.overload {
                OverloadCard(alert: overload).padding(.top, DSSpacing.s4)
            }
            factors
            if let history = model.summary.readinessHistory,
               history.compactMap(\.score).count >= ReadinessHistoryConstants.minimumScores {
                section(ReadinessHistoryConstants.title)
                ReadinessHistoryChart(history: history)
            }
            if let recovery {
                section(C.detailRecoveryTitle)
                RecoveryCard(estimate: recovery)
            }
            explanation.padding(.top, DSSpacing.sectionTop)
        }
        .padding(.horizontal, BrandConstants.screenPadding)
        .padding(.bottom, 32)
    }

    private func section(_ title: String) -> some View {
        DSSectionTitle(title)
            .padding(.top, DSSpacing.sectionTop)
            .padding(.bottom, DSSpacing.sectionBottom)
    }

    @ViewBuilder
    private var hero: some View {
        let score = model.summary.readiness?.score ?? model.fallbackScore
        VStack(alignment: .leading, spacing: 10) {
            if let score {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(score)")
                        .font(BrandFonts.number(56))
                        .foregroundStyle(ReadinessRuler.color(for: score))
                    Text(C.verdictPhrases[model.summary.verdict ?? readinessVerdict(score: score)] ?? "")
                        .font(.headline)
                        .foregroundStyle(BrandColors.text)
                }
                ReadinessRuler(score: score, showsLabels: true)
                if model.summary.readiness == nil {
                    Text(C.garminReadinessNote).font(.footnote).foregroundStyle(BrandColors.dim)
                } else if let reason = model.readinessReason {
                    Text(reason).font(.subheadline).foregroundStyle(BrandColors.text.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                }
                averages
            } else {
                Text(C.readinessEmpty).foregroundStyle(BrandColors.dim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        .padding(.top, DSSpacing.s2)
    }

    @ViewBuilder
    private var averages: some View {
        let parts = [(C.detailNormalLabel, model.readinessNormal), (C.detailWeekLabel, model.readinessWeekAverage)].compactMap { label, value in value.map { (label, $0) } }
        if !parts.isEmpty {
            HStack(spacing: DSSpacing.s4) {
                ForEach(parts, id: \.0) { label, value in
                    (Text(label + " ").foregroundStyle(BrandColors.dim) + Text("\(value)").bold().foregroundStyle(BrandColors.text))
                        .font(.footnote)
                }
            }
        }
    }

    @ViewBuilder
    private var factors: some View {
        let rows = model.factorRows
        if !rows.isEmpty {
            section(C.detailFactorsTitle)
            let scale = ReadinessFactorScale.of(rows)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider().overlay(BrandColors.line) }
                    ReadinessFactorDetail(row: row, scale: scale)
                }
                if let stress = model.readinessDay.stress {
                    Text(String(format: C.stressContextFormat, stress)).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }

    private var explanation: some View {
        DisclosureGroup {
            Text(C.detailExplanation)
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DSSpacing.s2)
        } label: {
            Text(C.detailExplanationTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
        }
        .tint(BrandColors.dim)
        .brandCard()
    }
}
