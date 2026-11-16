import Insights
import SwiftUI
import TrainingCore

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
                    if let program = model.program {
                        Text(StrengthText.programLabel(program.title, start: program.start.flatMap(Day.init(iso:)), end: program.end.flatMap(Day.init(iso:))))
                            .font(.footnote)
                            .foregroundStyle(BrandColors.dim)
                    }
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
            .brandRefreshable {
                let synced = await app.syncNow(.pull)
                let loaded = await load()
                return synced && loaded
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
            .task(id: app.mfitAccount.revision) {
                await app.mfitAccount.adoptTeacherWithProgram()
                await load()
            }
        }
    }

    @discardableResult
    private func load() async -> Bool {
        await model.load(container: app.container, client: app.mfitAccount.client, plan: app.trainer.plan)
    }
}
