import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct NextRaceView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass
    let raceId: UUID
    @State private var model: NextRaceModel?
    @State private var showsEditor = false

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let model, model.isLoaded, let info = model.info {
                    header(model, info: info)
                    pair {
                        goalTile(model, info: info)
                        RaceChecklistCard(items: model.checklist)
                    }
                    if let taper = model.taper {
                        RaceTaperCard(plan: taper)
                    }
                    PaceStrategyCard(model: model)
                    RaceStrategyUploadCard(info: info, strategy: model.strategy, client: app.garminAccount.client)
                    RaceCoursePointsCard(raceId: info.id, distance: info.distance, profile: model.profile, targetSeconds: model.target?.seconds ?? info.goalSeconds)
                    pair {
                        RaceBlockCard(block: model.block, today: model.today, reading: model.blockReading, longest: model.weeklyLongest)
                            .id(RacesConstants.blockAnchor)
                        RacePredictionCard(content: model.predictionContent)
                    }
                    Color.clear.frame(height: 1).id(RacesConstants.endAnchor)
                } else if model?.isLoaded == true {
                    Text(RacesConstants.emptyList).foregroundStyle(BrandColors.dim)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 24)
        }
        .onChange(of: model?.isLoaded) { _, loaded in
            guard loaded == true, let anchor = Self.debugScrollAnchor() else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        }
        .background(BrandBackground())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(RacesConstants.editRace) { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor, onDismiss: { Task { await reload() } }) {
            RaceEditorSheet(raceId: raceId)
        }
        .task { await reload() }
    }

    private static func debugScrollAnchor(defaults: UserDefaults = .standard) -> String? {
        #if DEBUG
        switch defaults.string(forKey: AppConstants.raceScrollDefaultsKey) {
        case "bloco": return RacesConstants.blockAnchor
        case .some: return RacesConstants.endAnchor
        case .none: return nil
        }
        #else
        return nil
        #endif
    }

    private func reload() async {
        let loaded = NextRaceModel(container: app.container, raceId: raceId, today: Day.today(), onChange: { app.remoteSync.scheduleSync() })
        await loaded.load()
        model = loaded
    }

    private func header(_ model: NextRaceModel, info: RaceInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.headerText ?? "")
                .font(.caption.weight(.medium))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(BrandColors.race)
            Text(info.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.text)
            let details = [RacesText.distanceText(info.distance), info.city, info.startTime.map { "largada \($0)" }].compactMap { $0 }
            Text(details.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
    }

    private func goalTile(_ model: NextRaceModel, info: RaceInfo) -> some View {
        let days = model.today.days(until: info.day)
        return VStack(alignment: .leading, spacing: 12) {
            SectionLabel(RacesConstants.goalTileTitle).padding(.top, 0).padding(.bottom, 0)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(max(days, 0))")
                    .font(BrandFonts.number(TodayConstants.compactCountdownFontSize))
                    .foregroundStyle(BrandColors.race)
                Text(RacesConstants.daysLabel).foregroundStyle(BrandColors.dim)
                if let pace = model.goalSummary?.goalPaceText {
                    Text(pace).font(.subheadline).foregroundStyle(BrandColors.dim)
                }
            }
            GoalBulletChart(today: model.outlook.today, raceDay: model.outlook.raceDay?.mid, goal: info.goalSeconds)
            Text(model.goalSummary?.sentence ?? (info.goalSeconds == nil ? RacesConstants.noGoal : RacesConstants.noPredictionForGoal))
                .font(.footnote)
                .foregroundStyle(BrandColors.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .brandCard(fillsHeight: true)
    }

    @ViewBuilder
    private func pair<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if sizeClass == .regular {
            ProportionalHStack(weights: RacesConstants.pairWeights, spacing: TodayConstants.rowSpacing) { content() }
        } else {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) { content() }
        }
    }

}
