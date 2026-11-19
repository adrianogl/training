import Insights
import SwiftUI

struct TodayWeekDetailView: View {
    @Environment(AppModel.self) private var app
    let model: TodayModel
    let trainer: [TrainerWorkout]
    let goal: Int
    var strength: StrengthModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
                let shown = model.shownWeekReport(trainer: trainer)
                WeeklyReportCard(report: shown, strength: strength?.weekSummary(start: shown.start), sources: app.trainer.strengthTally(weekStart: shown.start))
                if !model.shownWeek.isCurrent {
                    let current = model.currentWeekReport(trainer: trainer)
                    WeeklyReportCard(report: current, strength: strength?.weekSummary(start: current.start), sources: app.trainer.strengthTally(weekStart: current.start))
                }
                DSSectionTitle(WeeklyReportConstants.volumeTitle)
                    .padding(.top, DSSpacing.sectionTop - TodayConstants.rowSpacing)
                    .padding(.bottom, DSSpacing.sectionBottom - TodayConstants.rowSpacing)
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
