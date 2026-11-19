import GarminAPI
import SwiftUI
import TrainingCore

struct PlannedWorkoutRow: View {
    let plan: PlannedWorkout
    let isToday: Bool
    var isSelected = false
    var fallback: PaceBand?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Day(iso: plan.day).map { $0.chartDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(WorkoutConstants.locale)) } ?? plan.day)
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                    Text(PlanText.title(plan.title)).font(.headline).foregroundStyle(BrandColors.text).lineLimit(2)
                    DSChip(text: isToday ? WorkoutConstants.plannedToday : WorkoutConstants.plannedTag, tone: isToday ? .accent : .neutral, style: isToday ? .solid : .soft)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    if let meters = plan.estimatedMeters {
                        Text("\(TodayText.decimal(meters / WorkoutConstants.metersPerKilometer, fractionDigits: 1)) km")
                            .font(BrandFonts.number(20))
                            .foregroundStyle(BrandColors.dim)
                            .fixedSize()
                    }
                    if let range = PlannedTimeEstimate.total(plan, fallback: fallback) {
                        Text(RunTimeText.range(range))
                            .font(BrandFonts.number(15))
                            .foregroundStyle(BrandColors.text)
                            .fixedSize()
                    }
                }
            }
            PlannedShape(steps: plan.steps).frame(height: 14)
            CardLinkFooter(title: CardLinkConstants.workout).padding(.top, 4)
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

