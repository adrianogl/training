import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct NextRaceView: View {
    @Environment(AppModel.self) private var app
    let raceId: UUID
    @State private var model: NextRaceModel?
    @State private var showsEditor = false

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let model, model.isLoaded, let info = model.info {
                    header(model, info: info)
                    goalCard(model)
                    PaceStrategyCard(model: model)
                    RacePredictionCard(content: model.predictionContent)
                    RaceBlockCard(block: model.block, today: model.today, reading: model.blockReading)
                        .id(RacesConstants.blockAnchor)
                    RaceChecklistCard(items: model.checklist)
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

    @ViewBuilder
    private func goalCard(_ model: NextRaceModel) -> some View {
        if let summary = model.goalSummary {
            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    column(RacesConstants.goalLabel, WorkoutFormat.clock(summary.goalSeconds), summary.goalPaceText, color: BrandColors.text, detailColor: BrandColors.dim)
                    column(
                        RacesConstants.todayLabel,
                        summary.todaySeconds.map(WorkoutFormat.clock) ?? "—",
                        RacesText.signedClock(summary.todaySeconds, minus: summary.goalSeconds),
                        color: BrandColors.text, detailColor: deltaColor(summary.todaySeconds, summary.goalSeconds)
                    )
                    column(
                        RacesConstants.raceDayLabel,
                        summary.raceDaySeconds.map(WorkoutFormat.clock) ?? "—",
                        RacesText.signedClock(summary.raceDaySeconds, minus: summary.goalSeconds),
                        color: BrandColors.accent, detailColor: deltaColor(summary.raceDaySeconds, summary.goalSeconds)
                    )
                }
                Text(summary.sentence ?? RacesConstants.noPredictionForGoal)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.text.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .glassCard()
        } else {
            Text(RacesConstants.noGoal)
                .font(.subheadline)
                .foregroundStyle(BrandColors.dim)
                .glassCard()
        }
    }

    private func column(_ label: String, _ value: String, _ detail: String?, color: Color, detailColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(color == BrandColors.text ? BrandColors.dim : color)
            Text(value).font(BrandFonts.number(24)).foregroundStyle(color)
            Text(detail ?? " ").font(.caption).foregroundStyle(detailColor)
        }
        .frame(maxWidth: .infinity)
    }

    private func deltaColor(_ value: Double?, _ goal: Double) -> Color {
        guard let value else { return BrandColors.dim }
        return value <= goal ? BrandColors.accent : BrandColors.form
    }
}
