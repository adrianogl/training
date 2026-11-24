import SwiftUI

struct WorkoutsHubView: View {
    @Binding var trainerPath: [TrainerRoute]
    @AppStorage(WorkoutCalendarConstants.modeKey) private var modeRaw = WorkoutListMode.list.rawValue

    private var mode: WorkoutListMode { WorkoutListMode(rawValue: modeRaw) ?? .list }

    var body: some View {
        if mode == .week {
            NavigationStack(path: $trainerPath) {
                TrainerView(part: .week, header: AnyView(WorkoutsHeader(modeRaw: $modeRaw, onPlan: openPlan)))
            }
        } else {
            WorkoutListView(onPlan: openPlan)
        }
    }

    private func openPlan() {
        modeRaw = WorkoutListMode.week.rawValue
        trainerPath = [.plan]
    }
}
