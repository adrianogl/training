import Insights
import SwiftUI
import TrainingCore

struct StrengthView: View {
    @Environment(AppModel.self) private var app
    @State private var model = StrengthModel()
    @State private var path: [StrengthRoute] = []
    @State private var rowWidth: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = StrengthConstants

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
                    if sizeClass == .regular {
                        wideContent
                    } else {
                        SectionLabel(StrengthText.today)
                        StrengthTodayCard(model: model)
                        SectionLabel(StrengthText.week)
                        StrengthWeekCard(model: model)
                        SectionLabel(StrengthText.upcoming)
                        StrengthUpcomingCard(model: model)
                        SectionLabel(StrengthText.weekMuscles)
                        StrengthMusclesCard(model: model)
                        SectionLabel(StrengthText.loadsTitle)
                        StrengthLoadsCard(model: model)
                        SectionLabel(StrengthText.history)
                        StrengthHistoryCard(model: model)
                    }
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
                case .loads: StrengthLoadsView(model: model)
                case .load(let key): StrengthLoadDetailView(model: model, key: key)
                }
            }
            .task(id: app.mfitAccount.revision) {
                await app.mfitAccount.adoptTeacherWithProgram()
                await load()
            }
        }
    }

    private var sideWidth: CGFloat {
        max(0, (rowWidth - C.wideColumnSpacing) * C.wideSideShare)
    }

    private var wideContent: some View {
        VStack(spacing: C.wideColumnSpacing) {
            HStack(alignment: .top, spacing: C.wideColumnSpacing) {
                StrengthTodayWideCard(model: model)
                VStack(spacing: C.wideColumnSpacing) {
                    StrengthWeekListCard(model: model)
                    StrengthUpcomingCard(model: model, showsHeader: true)
                }
                .frame(width: sideWidth)
            }
            HStack(alignment: .top, spacing: C.wideColumnSpacing) {
                VStack(spacing: C.wideColumnSpacing) {
                    StrengthMusclesWideCard(model: model)
                    StrengthLoadsCard(model: model, showsHeader: true)
                }
                StrengthHistoryWideCard(model: model).frame(width: sideWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .padding(.top, 6)
    }

    @discardableResult
    private func load() async -> Bool {
        await model.load(container: app.container, client: app.mfitAccount.client, plan: app.trainer.plan)
    }
}
