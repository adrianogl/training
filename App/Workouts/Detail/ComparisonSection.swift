import SwiftUI

struct ComparisonSection: View {
    let title: String
    let rows: [ComparisonRow]
    let evolution: String?
    let sameStructure: Bool
    let showsTarget: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            line(title, "pace", "FC", showsTarget ? "no alvo" : nil, header: true, current: false)
            ForEach(rows) { row in
                Divider().overlay(BrandColors.line)
                line(row.dateText, row.paceText ?? "—", row.heartRateText ?? "—", showsTarget ? row.inTargetText ?? "—" : nil, header: false, current: row.isCurrent)
            }
            if let evolution {
                Text(evolution)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.dim)
                    .padding(.top, 10)
            }
            if !sameStructure {
                Text("A estrutura do treino mudou entre as ocorrências. A comparação usa só os blocos em comum.")
                    .font(.footnote)
                    .foregroundStyle(BrandColors.attention)
                    .padding(.top, 6)
            }
        }
        .glassCard()
    }

    private func line(_ name: String, _ pace: String, _ heartRate: String, _ target: String?, header: Bool, current: Bool) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(pace)
                .frame(width: WorkoutDetailConstants.comparisonValueWidth, alignment: .trailing)
            Text(heartRate)
                .frame(width: WorkoutDetailConstants.comparisonValueWidth, alignment: .trailing)
            if let target {
                Text(target)
                    .frame(width: WorkoutDetailConstants.comparisonValueWidth, alignment: .trailing)
            }
        }
        .font(header ? .caption2.weight(.semibold) : current ? BrandFonts.number(16) : BrandFonts.number(15))
        .textCase(header ? .uppercase : nil)
        .foregroundStyle(header ? BrandColors.dim : current ? BrandColors.accent : BrandColors.text)
        .padding(.vertical, 7)
    }
}
