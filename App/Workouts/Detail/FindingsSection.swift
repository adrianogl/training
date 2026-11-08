import SwiftUI
import WorkoutAnalysis

struct FindingsSection: View {
    let assessment: WorkoutAssessment
    let reading: WorkoutReading

    var body: some View {
        let positives = assessment.positives.count
        let negatives = assessment.negatives.count
        VStack(alignment: .leading, spacing: 14) {
            group("Positivos", symbol: "▲", color: BrandColors.accent, texts: slice(0, positives))
            group("Negativos", symbol: "▼", color: BrandColors.race, texts: slice(positives, negatives))
            group("Atenção", symbol: "●", color: BrandColors.attention, texts: slice(positives + negatives, assessment.attention.count))
            if reading.findingsOnDevice {
                OnDeviceCaption()
            }
        }
        .glassCard()
    }

    private func slice(_ start: Int, _ count: Int) -> [String] {
        let end = min(start + count, reading.findings.count)
        guard start < end else { return [] }
        return Array(reading.findings[start..<end])
    }

    private func group(_ title: String, symbol: String, color: Color, texts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            if texts.isEmpty {
                Text("Nenhum")
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.dim)
            }
            ForEach(Array(texts.enumerated()), id: \.offset) { _, text in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(color)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
