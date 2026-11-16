import GarminAPI
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
        .task(id: app.garminAccount.isSignedIn) {
            guard let client = app.garminAccount.client else { workout = nil; return }
            let today = Day.today()
            workout = (try? await StrengthWorkouts.fetch(client: client, from: today, through: today))?.first
        }
    }
}
