import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct NextRaceView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass
    let raceId: UUID
    @State private var model: NextRaceModel?
    @State private var showsEditor = false
    @State private var showsChat = false

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if model?.isStale == true {
                    RefreshingLabel()
                }
                if let model, model.isLoaded, let info = model.info {
                    header(model, info: info)
                    heroCard(model, info: info)
                    SectionHeader(RacesConstants.readySection)
                    pair {
                        RaceChecklistCard(items: model.checklist)
                        RaceBlockCard(block: model.block, today: model.today, reading: model.blockReading, longest: model.weeklyLongest)
                            .id(RacesConstants.blockAnchor)
                    }
                    if let taper = model.taper {
                        SectionHeader(RacesConstants.taperSection)
                        RaceTaperCard(plan: taper)
                    }
                    SectionHeader(RacesConstants.raceDaySection)
                    RaceDayCard(model: model, info: info, client: app.garminAccount.client)
                    AskIntelligenceButton(title: WorkoutChatConstants.askRace) { showsChat = true }
                        .padding(.top, 8)
                    Color.clear.frame(height: 1).id(RacesConstants.endAnchor)
                } else if model?.isLoaded == true {
                    Text(RacesConstants.emptyList).foregroundStyle(BrandColors.dim)
                } else {
                    SkeletonCards(heights: SkeletonConstants.racesHeights)
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
        .sheet(isPresented: $showsChat) {
            if let model, let info = model.info {
                WorkoutChatSheet(activityId: RaceChatContextBuilder.key(raceId), context: chatContext(model, info: info), store: .races)
                    .presentationSizing(.page)
            }
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
        if model == nil {
            model = await NextRaceModel.restored(container: app.container, raceId: raceId, snapshots: app.snapshots, onChange: { app.remoteSync.scheduleSync() })
        }
        let loaded = NextRaceModel(container: app.container, raceId: raceId, today: Day.today(), onChange: { app.remoteSync.scheduleSync() }, snapshots: app.snapshots)
        await loaded.load()
        guard !Task.isCancelled else { return }
        model = loaded
    }

    private func chatContext(_ model: NextRaceModel, info: RaceInfo) -> WorkoutChatContext {
        RaceChatContextBuilder.next(
            info: info, today: model.today,
            outlook: RaceOutlookFacts(today: model.outlook.today, raceDay: model.outlook.raceDay?.mid, sentence: model.goalSummary?.sentence),
            checklist: model.checklist, blockReading: model.blockReading, strategy: model.strategy,
            block: model.block, taper: model.taper, targetText: model.targetText
        )
    }

    private func header(_ model: NextRaceModel, info: RaceInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: RacesConstants.priorityFormat, info.priority.rawValue))
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

    private func heroCard(_ model: NextRaceModel, info: RaceInfo) -> some View {
        let target = RaceTargetBuilder.target(info, todayPrediction: model.outlook.today, raceDayPrediction: model.outlook.raceDay?.mid, today: model.today)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(target.dateText) · \(target.distanceText)")
                    .font(.caption.weight(.semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColors.dim)
                Spacer()
                Text("\(target.days)")
                    .font(BrandFonts.number(RacesConstants.targetDaysFontSize))
                    .foregroundStyle(BrandColors.race)
                Text(RacesConstants.daysLabel).font(.caption).foregroundStyle(BrandColors.dim)
            }
            HStack(alignment: .top, spacing: 16) {
                heroValue(RacesConstants.predictionLabel, seconds: target.predictionSeconds, color: BrandColors.text)
                heroValue(RacesConstants.goalLabel, seconds: target.goalSeconds, color: BrandColors.accent)
            }
            if let weather = model.weather {
                RaceWeatherLine(reading: weather, goalSeconds: info.goalSeconds)
            }
            let caption = [target.gapText, model.goalSummary?.goalPaceText].compactMap { $0 }.joined(separator: " · ")
            if !caption.isEmpty {
                Text(caption).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
            }
            Text(model.goalSummary?.sentence ?? (info.goalSeconds == nil ? RacesConstants.noGoal : RacesConstants.noPredictionForGoal))
                .font(.footnote)
                .foregroundStyle(BrandColors.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private func heroValue(_ label: String, seconds: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(BrandColors.dim)
            Text(seconds.map(WorkoutFormat.clock) ?? "—")
                .font(BrandFonts.number(RacesConstants.heroClockFontSize))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
