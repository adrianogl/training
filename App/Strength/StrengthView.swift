import Insights
import SwiftUI

struct StrengthView: View {
    @Environment(AppModel.self) private var app
    @State private var model = StrengthModel()
    @State private var path: [StrengthRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    CompactLogoHeader()
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(WorkoutConstants.locale)))
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                    Text(StrengthText.title)
                        .font(BrandFonts.largeTitle)
                        .foregroundStyle(BrandColors.text)
                    SectionLabel(StrengthText.today)
                    StrengthTodayCard(model: model)
                    SectionLabel(StrengthText.week)
                    StrengthWeekCard(model: model)
                    SectionLabel(StrengthText.weekMuscles)
                    StrengthMusclesCard(model: model)
                    SectionLabel(StrengthText.history)
                    StrengthHistoryCard(model: model)
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: StrengthRoute.self) { route in
                switch route {
                case .workout(let id): StrengthWorkoutView(model: model, workoutId: id)
                case .session(let id): StrengthSessionView(model: model, sessionId: id)
                case .volume: StrengthVolumeView(model: model)
                case .history: StrengthHistoryView(model: model)
                }
            }
            .refreshable { await load() }
            .task(id: app.garminAccount.isSignedIn) { await load() }
        }
    }

    private func load() async {
        await model.load(container: app.container, client: app.garminAccount.client, plan: app.trainer.plan)
    }
}
