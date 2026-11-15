import Insights
import SwiftUI
import WorkoutAnalysis

struct TrainerPaceEditCard: View {
    let history: TrainerPaces
    let racePace: Double?
    let isGoal: Bool
    @Binding var overrides: [TrainerPaceKind: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(TrainerText.pacesTitle).padding(.vertical, 0)
            ForEach(TrainerConstants.paceKinds, id: \.self) { kind in
                if let base = historyValue(kind) {
                    row(kind, base: base)
                }
            }
        }
        .brandCard()
    }

    private func historyValue(_ kind: TrainerPaceKind) -> Double? {
        switch kind {
        case .easy: history.easy
        case .long: history.long
        case .threshold: history.threshold
        case .vo2max: history.vo2max
        case .race: racePace
        }
    }

    private func row(_ kind: TrainerPaceKind, base: Double) -> some View {
        let manual = overrides[kind]
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(TrainerText.paceKindName(kind, goal: isGoal)).font(.subheadline).foregroundStyle(BrandColors.text)
                if let manual {
                    Text("\(WorkoutFormat.clock(manual))/km · \(TrainerText.paceManual)")
                        .font(.caption)
                        .foregroundStyle(BrandColors.attention)
                } else {
                    Text("\(WorkoutFormat.clock(base))/km · \(TrainerText.paceFromHistory)")
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
            }
            Spacer(minLength: 6)
            if let manual {
                Stepper(
                    "", value: Binding(get: { manual }, set: { overrides[kind] = $0 }),
                    in: TrainerEngine.editPaceRange, step: TrainerEngine.editPaceStepSeconds
                )
                .labelsHidden()
                Button(TrainerText.paceBackToHistory) { overrides[kind] = nil }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.accent)
            } else {
                Button(TrainerText.paceAdjust) { overrides[kind] = base.rounded() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.accent)
            }
        }
    }
}

struct TrainerEditPreviewCard: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(TrainerText.previewTitle).padding(.vertical, 0)
            if lines.isEmpty {
                Text(TrainerText.previewEmpty).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            ForEach(lines, id: \.self) { line in
                Text(line).font(.footnote).foregroundStyle(BrandColors.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
