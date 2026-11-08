import SwiftUI
import WorkoutAnalysis

struct FindingsSection: View {
    let assessment: WorkoutAssessment
    let blocks: [WorkoutBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            group("Positivos", symbol: "▲", color: BrandColors.accent, findings: assessment.positives)
            group("Negativos", symbol: "▼", color: BrandColors.race, findings: assessment.negatives)
            group("Atenção", symbol: "●", color: BrandColors.attention, findings: assessment.attention)
        }
        .glassCard()
    }

    private func group(_ title: String, symbol: String, color: Color, findings: [Finding]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            if findings.isEmpty {
                Text("Nenhum")
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.dim)
            }
            ForEach(Array(findings.enumerated()), id: \.offset) { _, finding in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(color)
                    Text(FindingTemplates.text(finding, blocks: blocks))
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
