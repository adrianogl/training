import SwiftUI

struct GoalsManageView: View {
    @AppStorage(AppConstants.weeklyGoalDefaultsKey) private var weeklyGoal = 0

    private typealias C = GoalsConstants

    var body: some View {
        Form {
            Section {
                Stepper(value: $weeklyGoal, in: AppConstants.weeklyGoalRange, step: AppConstants.weeklyGoalStep) {
                    HStack {
                        Text(C.weeklyTitle)
                        Spacer()
                        Text(weeklyGoal > 0 ? String(format: C.weeklyKmFormat, weeklyGoal) : C.weeklyNone).foregroundStyle(BrandColors.dim)
                    }
                }
            } header: {
                DSSectionTitle(C.weeklyTitle)
            } footer: {
                Text(C.weeklyFooter)
            }
            GoalsSection()
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .navigationTitle(C.sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
