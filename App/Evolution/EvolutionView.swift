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
                        Text(EvolutionConstants.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(BrandColors.text)
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
                    guard loaded == true, Self.debugScrollsToEnd() else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(600))
                        proxy.scrollTo(EvolutionConstants.endAnchor, anchor: .bottom)
                    }
                }
            }
            .background(BrandBackground())
            .refreshable { await app.syncNow(.launch) }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: MetricKind.self) { kind in
                if let model {
                    MetricDetailView(model: MetricDetailModel(kind: kind, period: model.period, container: app.container, today: model.today))
                }
            }
        }
        .task(id: syncToken) {
            await Task.yield()
            let loaded = EvolutionModel(container: app.container, today: Day.today())
            await loaded.load()
            model = loaded
            await loaded.refreshSentence()
        }
    }

    @ViewBuilder
    private func content(_ model: EvolutionModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            OverallStateCard(title: model.verdictTitle, sentence: model.overallSentence, rows: model.indicatorRows)
            selectors(model)
            RacePredictionCard(content: model.highlight)
            cards(model)
            Color.clear.frame(height: 1).id(EvolutionConstants.endAnchor)
        }
    }

    private func selectors(_ model: EvolutionModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(EvolutionConstants.periodLabel, selection: Binding(
                get: { model.period },
                set: { period in Task { await model.select(period: period) } }
            )) {
                ForEach(MetricPeriodOption.all, id: \.period) { Text($0.title).tag($0.period) }
            }
            .pickerStyle(.segmented)
            Picker(EvolutionConstants.horizonLabel, selection: Binding(get: { model.horizon }, set: { model.horizon = $0 })) {
                ForEach(HorizonOption.all, id: \.horizon) { Text($0.title).tag($0.horizon) }
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private func cards(_ model: EvolutionModel) -> some View {
        if model.cardData.isEmpty && model.isLoadingCards {
            ProgressView(EvolutionConstants.loadingCards).frame(maxWidth: .infinity).padding(.top, 12)
        } else {
            let columns = [GridItem(.adaptive(minimum: EvolutionConstants.gridMinimumWidth), spacing: 12, alignment: .top)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.cards, id: \.self) { kind in
                    MetricCard(kind: kind, data: model.cardData[kind], chart: model.chart(for: kind))
                }
            }
            .opacity(model.isLoadingCards ? 0.5 : 1)
        }
    }

    private static func initialPath(defaults: UserDefaults = .standard) -> [MetricKind] {
        #if DEBUG
        return defaults.string(forKey: AppConstants.openMetricDefaultsKey).flatMap(MetricKind.init(rawValue:)).map { [$0] } ?? []
        #else
        return []
        #endif
    }

    private static func debugScrollsToEnd(defaults: UserDefaults = .standard) -> Bool {
        #if DEBUG
        return defaults.bool(forKey: AppConstants.evolutionScrollDefaultsKey)
        #else
        return false
        #endif
    }
}
