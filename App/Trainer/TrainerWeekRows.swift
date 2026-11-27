import Insights
import Storage
import SwiftData
import SwiftUI
import TrainingCore

struct TrainerWeekRows: View {
    let group: TrainerWeekGroup
    let currentDay: Day
    @Environment(AppModel.self) private var app
    @Query private var records: [ActivityRecord]
    @Query private var history: [ActivityRecord]
    @State private var recordTimeline = RecordTimelineCache()

    init(group: TrainerWeekGroup, currentDay: Day) {
        self.group = group
        self.currentDay = currentDay
        let from = Self.date(group.start)
        let to = Self.date(group.start.adding(days: 7))
        _records = Query(filter: #Predicate<ActivityRecord> { $0.start >= from && $0.start < to }, sort: \.start)
    }

    var body: some View {
        ForEach(TrainerWeekItems.items(rows: group.rows, done: WorkoutListModel.rows(records: records, timeline: recordTimeline.timeline(records: history)))) { item in
            switch item {
            case .planned(let row):
                NavigationLink(value: TrainerRoute.day(row.id)) {
                    TrainerDayRowView(
                        row: row, isToday: row.workout.day == currentDay,
                        adjusted: row.run == nil ? app.trainer.dayAdjusted(row.workout)?.workout : nil
                    )
                }
                .buttonStyle(.cardLink)
            case .plannedDone(let row, let done):
                TrainerPlannedDoneCard(row: row, done: done, newIds: app.newActivityIds)
            case .done(let row):
                NavigationLink(value: TrainerRoute.workout(row.activityId)) {
                    WorkoutRow(row: row, isFromPlan: true, isNew: app.newActivityIds.contains(row.activityId))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static func date(_ day: Day) -> Date {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? .distantPast
    }
}
