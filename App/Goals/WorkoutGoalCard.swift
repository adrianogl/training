import SwiftUI

struct WorkoutGoalCard: View {
    let entries: [WorkoutGoalEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DSCardLabel(WorkoutGoalConstants.cardTitle)
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 { Divider().overlay(BrandColors.line) }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title).font(.headline).foregroundStyle(BrandColors.text)
                        Spacer()
                        DSChip(text: entry.status, tone: entry.good ? .accent : .attention)
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
