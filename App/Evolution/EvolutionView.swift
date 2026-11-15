import Insights
import SwiftData
import SwiftUI
import TrainingCore

struct EvolutionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: EvolutionModel?
    @SceneStorage(NavigationRestorationConstants.evolutionPathKey) private var pathData = Data()
    @State private var appliedRestoration = false
    @State private var showsChat = false
    @SceneStorage(EvolutionConstants.groupStorageKey) private var selectedGroupTitle = EvolutionConstants.metricGroups.first?.title ?? ""

    @State private var path: [MetricKind] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        CompactLogoHeader()
                        SyncStatusPill()
                        if model?.isStale == true {
                            RefreshingLabel()
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text(EvolutionConstants.title)
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(BrandColors.text)
                            if sizeClass == .regular, let model, model.isLoaded {
                                Spacer()
                                periodPicker(model).frame(maxWidth: EvolutionConstants.periodPickerWidth)
                            }
                        }
                        .padding(.bottom, 14)
                        if let model, model.isLoaded, !app.showsSkeleton {
                            content(model)
                        } else if app.showsSkeleton {
                            FirstSyncView()
                        } else {
                            SkeletonCards(heights: SkeletonConstants.evolutionHeights)
                        }
                    }
                    .padding(.horizontal, BrandConstants.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .brandRefreshable { await app.syncNow(.pull) }
                .onChange(of: model?.isLoaded) { _, loaded in
                    guard loaded == true, let anchor = Self.debugScrollAnchor() else { return }
                    if anchor == EvolutionConstants.metricsAnchor { selectedGroupTitle = EvolutionConstants.predictionsGroupTitle }
                    Task {
                        try? await Task.sleep(for: .milliseconds(600))
                        proxy.scrollTo(anchor, anchor: .top)
                    }
                }
            }
            .background(BrandBackground())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: MetricKind.self) { kind in
                if let model {
                    MetricDetailView(model: MetricDetailModel(kind: kind, period: model.period, container: app.container, today: model.today))
                }
            }
        }
        .sheet(isPresented: $showsChat) {
            if let model {
                WorkoutChatSheet(activityId: WorkoutChatConstants.evolutionKey, context: chatContext(model), store: .evolution)
                    .presentationSizing(.page)
            }
        }
        .onAppear {
            guard !appliedRestoration else { return }
            appliedRestoration = true
            path = NavigationRestoration.decodePath(pathData)
            let debugPath = Self.initialPath()
            if !debugPath.isEmpty { path = debugPath }
        }
        .onChange(of: path) { _, value in pathData = NavigationRestoration.encode(value) }
        .task(id: app.dataToken) {
            await Task.yield()
            if model == nil {
                model = await EvolutionModel.restored(container: app.container, snapshots: app.snapshots)
            }
            let loaded = EvolutionModel(
                container: app.container,
                today: Day.today(),
                period: model?.period ?? EvolutionConstants.defaultPeriod,
                snapshots: app.snapshots
            )
            await loaded.load()
            guard !Task.isCancelled else { return }
            model = loaded
            await loaded.refreshSentence()
        }
    }

    @ViewBuilder
    private func content(_ model: EvolutionModel) -> some View {
        VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
            if sizeClass != .regular {
                periodPicker(model)
            }
            SectionHeader(EvolutionConstants.summaryTitle)
            OverallStateCard(title: model.verdictTitle, sentence: model.overallSentence, indicators: model.indicators)
            SectionHeader(EvolutionConstants.metricsTitle).id(EvolutionConstants.metricsAnchor)
            groupChips
            groups(model)
            SectionHeader(EvolutionConstants.historyTitle)
            row(weights: [1, 1]) {
                RecordsCard(records: model.records, now: .now)
                ZoneWeeksCard(weeks: model.zoneWeeks)
            }
            HeatmapCard(columns: model.heatmapColumns)
            AskIntelligenceButton(title: WorkoutChatConstants.askEvolution) { showsChat = true }
            Color.clear.frame(height: 1).id(EvolutionConstants.endAnchor)
        }
    }

    private func chatContext(_ model: EvolutionModel) -> WorkoutChatContext {
        EvolutionChatContextBuilder.context(
            verdictTitle: model.verdictTitle, sentence: model.overallSentence, indicators: model.indicators,
            outlook: model.outlook, countdownDays: model.raceContext.countdownDays,
            cards: Array(model.cardData.values), records: model.records, zoneWeeks: model.zoneWeeks,
            goals: (try? goalSnapshots(context: ModelContext(app.container), today: Day.today())) ?? []
        )
    }

    private func periodPicker(_ model: EvolutionModel) -> some View {
        Picker(EvolutionConstants.periodLabel, selection: Binding(
            get: { model.period },
            set: { period in Task { await model.select(period: period) } }
        )) {
            ForEach(MetricPeriodOption.all, id: \.period) { Text($0.title).tag($0.period) }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func groups(_ model: EvolutionModel) -> some View {
        if model.cardData.isEmpty && model.isLoadingCards {
            ProgressView(EvolutionConstants.loadingCards).frame(maxWidth: .infinity).padding(.top, 12)
        } else {
            if let group = MetricGroup.selected(selectedGroupTitle) {
                MetricGroupCard(group: group, data: model.cardData)
                    .opacity(model.isLoadingCards ? 0.5 : 1)
            }
        }
    }

    private var groupChips: some View {
        let selected = MetricGroup.selected(selectedGroupTitle)?.title
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EvolutionConstants.groupChipSpacing) {
                ForEach(EvolutionConstants.metricGroups) { group in
                    let isSelected = group.title == selected
                    Button { selectedGroupTitle = group.title } label: {
                        Text(group.title)
                            .font(.footnote)
                            .foregroundStyle(isSelected ? BrandColors.accent : BrandColors.text.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSelected ? BrandColors.accentGlow : BrandColors.track, in: Capsule())
                            .overlay(Capsule().strokeBorder(isSelected ? BrandColors.accent.opacity(0.5) : BrandColors.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private func row<Content: View>(weights: [Double], @ViewBuilder content: () -> Content) -> some View {
        if sizeClass == .regular {
            ProportionalHStack(weights: weights, spacing: TodayConstants.rowSpacing) { content() }
        } else {
            VStack(spacing: TodayConstants.rowSpacing) { content() }
        }
    }

    private static func initialPath(defaults: UserDefaults = .standard) -> [MetricKind] {
        #if DEBUG
        return defaults.string(forKey: AppConstants.openMetricDefaultsKey).flatMap(MetricKind.init(rawValue:)).map { [$0] } ?? []
        #else
        return []
        #endif
    }

    private static func debugScrollAnchor(defaults: UserDefaults = .standard) -> String? {
        #if DEBUG
        switch defaults.string(forKey: AppConstants.evolutionScrollDefaultsKey) {
        case "destaque": return EvolutionConstants.metricsAnchor
        case .some: return EvolutionConstants.endAnchor
        case .none: return nil
        }
        #else
        return nil
        #endif
    }
}
