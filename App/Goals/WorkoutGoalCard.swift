import SwiftUI

struct WorkoutGoalCard: View {
    let entries: [WorkoutGoalEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(WorkoutGoalConstants.cardTitle).padding(.top, 0).padding(.bottom, 0)
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { Divider().overlay(BrandColors.line) }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title).font(.headline).foregroundStyle(BrandColors.text)
                        Spacer()
                        Text(entry.status)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .foregroundStyle(entry.good ? BrandColors.accent : BrandColors.attention)
                            .background((entry.good ? BrandColors.accentFill : BrandColors.attention).opacity(0.15), in: Capsule())
                    }
                    ForEach(entry.lines, id: \.self) { line in
                        Text(line).font(.subheadline).foregroundStyle(BrandColors.text.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .brandCard()
    }
}
