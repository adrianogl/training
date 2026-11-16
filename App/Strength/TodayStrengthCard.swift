import GarminAPI
import MFIT
import SwiftUI
import TrainingCore

struct TodayStrengthCard<Label: View>: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    var showsLabel: Bool
    @ViewBuilder var label: () -> Label
    @State private var workout: StrengthWorkout?

    var body: some View {
        Group {
            if let workout {
                if showsLabel { label() }
                Button {
                    if let url = URL(string: "\(AppConstants.urlScheme)://\(AppSection.strength.path)") { openURL(url) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(StrengthText.todaySource).font(.caption).foregroundStyle(BrandColors.dim)
                            Spacer()
                            Text(StrengthText.open).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                        }
                        Text(workout.title).font(.headline).foregroundStyle(BrandColors.text)
                        Text(StrengthText.countLabel(exercises: workout.blocks.flatMap(\.exercises).count, sets: workout.totalSets))
                            .font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    .brandCard()
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: app.mfitAccount.revision) {
            await app.mfitAccount.adoptTeacherWithProgram()
            guard let client = app.mfitAccount.client else { workout = nil; return }
            let today = Day.today()
            let store = StrengthProgramStore()
            let schedule = StrengthSchedule()
            workout = schedule.workouts(store.load().program, from: today, through: today).first
            guard let fetched = try? await client.currentProgram(today: today.iso) as MFITProgram?? else { return }
            let cache = fetched.map(store.update(with:)) ?? store.clearProgram()
            workout = schedule.workouts(cache.program, from: today, through: today).first
        }
    }
}
