import Insights
import SwiftUI

struct TodayWeekDetailView: View {
    let model: TodayModel
    let trainer: [TrainerWorkout]
    let goal: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
                WeeklyReportCard(report: model.shownWeekReport(trainer: trainer))
                if !model.shownWeek.isCurrent {
                    WeeklyReportCard(report: model.currentWeekReport(trainer: trainer))
                }
                VolumeHistoryCard(week: model.summary.week, goal: goal, planned: model.plannedWeeks)
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(BrandBackground())
        .navigationTitle(WeeklyReportConstants.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
