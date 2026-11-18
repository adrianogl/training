import GarminAPI
import SwiftUI
import TrainingCore

struct StrengthPlannedRow: View {
    let workout: StrengthWorkout
    let isToday: Bool
    var isSelected = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Day(iso: workout.day).map { $0.chartDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(WorkoutConstants.locale)) } ?? workout.day)
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                Text(workout.title).font(.headline).foregroundStyle(BrandColors.text).lineLimit(2)
                HStack(spacing: 6) {
                    DSChip(text: WorkoutConstants.strengthTag, tone: .strength)
                    DSChip(text: isToday ? WorkoutConstants.plannedToday : WorkoutConstants.plannedTag, tone: isToday ? .accent : .neutral, style: isToday ? .solid : .soft)
                }
            }
            Spacer(minLength: 8)
            Text(String(format: WorkoutConstants.strengthSetsFormat, workout.totalSets))
                .font(BrandFonts.number(20))
                .foregroundStyle(BrandColors.dim)
            CardLinkBadge()
        }
        .padding(BrandConstants.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
                .strokeBorder(isSelected ? BrandColors.accentFill : BrandColors.line, style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: isSelected ? [] : [5, 4]))
        )
        .contentShape(Rectangle())
    }
}
