import Insights
import SwiftUI
import TrainingCore

struct EvolutionView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model: EvolutionModel?
    @State private var path: [MetricKind] = EvolutionView.initialPath()

    private var syncToken: Date? {
        if case .finished(let date) = app.syncStatus { return date }
        return nil
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        CompactLogoHeader()
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
                        if let model, model.isLoaded {
                            content(model)
                        } else {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, BrandConstants.screenPadding)
                    .padding(.top, 8)
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
            .refreshable { await app.syncNow(.pull) }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: MetricKind.self) { kind in
                if let model {
                    MetricDetailView(model: MetricDetailModel(kind: kind, period: model.period, container: app.container, today: model.today))
                }
            }
        }
        .task(id: syncToken) {
            await Task.yield()
            let loaded = EvolutionModel(
                container: app.container,
                today: Day.today(),
                period: model?.period ?? EvolutionConstants.defaultPeriod,
                horizon: model?.horizon ?? Self.initialHorizon()
            )
            await loaded.load()
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
            row(weights: [1, 1]) {
                OverallStateCard(title: model.verdictTitle, sentence: model.overallSentence, indicators: model.indicators)
                RacePredictionCard(content: model.highlight, horizon: Binding(get: { model.horizon }, set: { model.horizon = $0 }))
                    .id(EvolutionConstants.highlightAnchor)
            }
            IndicatorsCard(indicators: model.indicators)
            SectionLabel(EvolutionConstants.metricsTitle)
            groups(model)
            row(weights: [1, 1]) {
                ZoneWeeksCard(weeks: model.zoneWeeks)
                RecordsCard(records: model.records, now: .now)
            }
            HeatmapCard(columns: model.heatmapColumns)
            Color.clear.frame(height: 1).id(EvolutionConstants.endAnchor)
        }
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
            let groups = EvolutionConstants.metricGroups
            let pairs = stride(from: 0, to: groups.count, by: 2).map { Array(groups[$0..<min($0 + 2, groups.count)]) }
            VStack(spacing: TodayConstants.rowSpacing) {
                ForEach(pairs, id: \.first?.id) { pair in
                    row(weights: [1, 1]) {
                        ForEach(pair) { group in MetricGroupCard(group: group, data: model.cardData) }
                    }
                }
            }
            .opacity(model.isLoadingCards ? 0.5 : 1)
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
        case "destaque": return EvolutionConstants.highlightAnchor
        case .some: return EvolutionConstants.endAnchor
        case .none: return nil
        }
        #else
        return nil
        #endif
    }

    private static func initialHorizon(defaults: UserDefaults = .standard) -> ProjectionHorizon {
        #if DEBUG
        return defaults.string(forKey: AppConstants.evolutionHorizonDefaultsKey).flatMap(ProjectionHorizon.init(rawValue:)) ?? .untilRace
        #else
        return .untilRace
        #endif
    }
}
