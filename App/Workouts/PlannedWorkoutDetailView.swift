import GarminAPI
import Storage
import SwiftData
import SwiftUI
import TrainingCore

struct PlannedWorkoutDetailView: View {
    let plan: PlannedWorkout
    @Query(sort: \ActivityRecord.start, order: .reverse) private var records: [ActivityRecord]

    private typealias C = WorkoutConstants

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateText).font(.subheadline).foregroundStyle(BrandColors.dim)
                    Text(plan.title).font(.title2.bold()).foregroundStyle(BrandColors.text)
                    HStack(spacing: 8) {
                        TreinusBadge()
                        Text(C.plannedDetailSubtitle).font(.subheadline).foregroundStyle(BrandColors.dim)
                    }
                    if let estimate = PlanText.estimate(plan) {
                        Text(estimate).font(BrandFonts.number(22)).foregroundStyle(BrandColors.text).padding(.top, 8)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(C.plannedStructure).padding(.top, 0).padding(.bottom, 0)
                    PlannedShape(steps: plan.steps).frame(height: TodayConstants.planShapeHeight * 1.5)
                }
                .brandCard()
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(C.plannedSteps).padding(.top, 0).padding(.bottom, 0)
                    PlannedStepsList(steps: plan.steps)
                }
                .brandCard()
                if !previous.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(C.plannedLastTime).padding(.top, 0).padding(.bottom, 0)
                        ForEach(previous, id: \.activityId) { record in
                            let row = WorkoutListModel.row(record)
                            Text(String(format: C.plannedLastTimeFormat, row.dateText, TodayText.decimal(row.kilometers ?? 0, fractionDigits: 1), row.paceText ?? ""))
                                .font(.subheadline)
                                .foregroundStyle(BrandColors.text)
                        }
                    }
                    .brandCard()
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.vertical, 16)
        }
        .background(BrandBackground())
    }

    private var previous: [ActivityRecord] {
        Array(records.filter { $0.workoutName == plan.title }.prefix(3))
    }

    private var dateText: String {
        guard let day = Day(iso: plan.day) else { return plan.day }
        return day.chartDate.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(WorkoutConstants.locale))
    }
}

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
