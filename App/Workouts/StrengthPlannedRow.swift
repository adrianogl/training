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
                    Text(WorkoutConstants.strengthTag)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BrandColors.strength)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(BrandColors.strength.opacity(0.14), in: Capsule())
                    Text(isToday ? WorkoutConstants.plannedToday : WorkoutConstants.plannedTag)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isToday ? BrandColors.onAccent : BrandColors.dim)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(isToday ? BrandColors.accentFill : BrandColors.track, in: Capsule())
                }
            }
            Spacer(minLength: 8)
            Text(String(format: WorkoutConstants.strengthSetsFormat, workout.totalSets))
                .font(BrandFonts.number(20))
                .foregroundStyle(BrandColors.dim)
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
