import GarminAPI
import SwiftUI
import TrainingCore

struct PlannedWorkoutRow: View {
    let plan: PlannedWorkout
    let isToday: Bool
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Day(iso: plan.day).map { $0.chartDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(WorkoutConstants.locale)) } ?? plan.day)
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                    Text(plan.title).font(.headline).foregroundStyle(BrandColors.text).lineLimit(2)
                    Text(isToday ? WorkoutConstants.plannedToday : WorkoutConstants.plannedTag)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isToday ? BrandColors.onAccent : BrandColors.dim)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(isToday ? BrandColors.accentFill : BrandColors.track, in: Capsule())
                }
                Spacer(minLength: 8)
                if let meters = plan.estimatedMeters {
                    Text("\(TodayText.decimal(meters / WorkoutConstants.metersPerKilometer, fractionDigits: 1)) km")
                        .font(BrandFonts.number(20))
                        .foregroundStyle(BrandColors.dim)
                }
            }
            PlannedShape(steps: plan.steps).frame(height: 14)
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

