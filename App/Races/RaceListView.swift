import Insights
import Storage
import SwiftData
import SwiftUI
import TrainingCore

struct RaceListView: View {
    @Environment(AppModel.self) private var app
    @Query private var races: [RaceRecord]
    @State private var model: RaceListModel?
    @State private var path: [RaceRoute] = []
    @State private var showsEditor = false
    @State private var openedDebugRace = false

    private var signature: [Date] {
        races.map(\.updatedAt).sorted()
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(RacesConstants.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(BrandColors.text)
                        Spacer()
                        Button {
                            showsEditor = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(BrandColors.onAccent)
                                .frame(width: 40, height: 40)
                                .background(BrandColors.accent, in: Circle())
                        }
                        .accessibilityLabel(RacesConstants.addRace)
                    }
                    .padding(.bottom, 8)
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
            .background(BrandBackground())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: RaceRoute.self) { route in
                switch route {
                case .next(let id):
                    NextRaceView(raceId: id)
                case .completed(let id):
                    if let model, let summary = model.summaries[id] {
                        CompletedRaceView(summary: summary, model: model)
                    }
                }
            }
            .navigationDestination(for: Int64.self) { activityId in
                WorkoutDetailView(activityId: activityId)
            }
        }
        .sheet(isPresented: $showsEditor) {
            RaceEditorSheet(raceId: nil)
        }
        .task(id: signature) {
            await Task.yield()
            let loaded = RaceListModel(container: app.container, today: Day.today())
            await loaded.load()
            model = loaded
            openDebugRaceIfNeeded(loaded)
        }
    }

    @ViewBuilder
    private func content(_ model: RaceListModel) -> some View {
        if model.upcoming.isEmpty && model.completed.isEmpty && model.candidates.isEmpty {
            Text(RacesConstants.emptyList)
                .font(.subheadline)
                .foregroundStyle(BrandColors.dim)
                .glassCard()
        }
        if !model.upcoming.isEmpty {
            SectionLabel(RacesConstants.upcomingTitle)
            ForEach(model.upcoming) { row in
                NavigationLink(value: RaceRoute.next(row.id)) { RaceRow(row: row) }
                    .buttonStyle(.plain)
            }
        }
        if !model.candidates.isEmpty {
            SectionLabel(RacesConstants.candidatesTitle)
            ForEach(model.candidates) { candidate in
                RaceCandidateRow(
                    candidate: candidate,
                    onConfirm: { Task { await model.confirm(candidate.activityId) } },
                    onDecline: { Task { await model.decline(candidate.activityId) } }
                )
            }
        }
        if !model.completed.isEmpty {
            SectionLabel(RacesConstants.completedTitle)
            ForEach(model.completed) { row in
                NavigationLink(value: RaceRoute.completed(row.id)) { RaceRow(row: row) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func openDebugRaceIfNeeded(_ model: RaceListModel) {
        #if DEBUG
        guard !openedDebugRace, let target = UserDefaults.standard.string(forKey: AppConstants.openRaceDefaultsKey) else { return }
        openedDebugRace = true
        switch target {
        case "proxima":
            if let first = model.upcoming.first { path = [.next(first.id)] }
        case "concluida":
            if let first = model.completed.first { path = [.completed(first.id)] }
        case "nova":
            showsEditor = true
        default:
            break
        }
        #endif
    }
}

private struct RaceRow: View {
    let row: RaceRowData

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(row.priority)
                .font(BrandFonts.number(20))
                .foregroundStyle(row.isUpcoming ? BrandColors.race : BrandColors.dim)
                .frame(width: 34, height: 34)
                .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(row.dateText).font(.caption).foregroundStyle(BrandColors.dim)
                HStack(spacing: 6) {
                    Text(row.name).font(.headline).foregroundStyle(BrandColors.text).lineLimit(2)
                    if row.isPR {
                        Text(RacesConstants.prBadge)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(BrandColors.onAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BrandColors.accent, in: Capsule())
                    }
                }
                if let detail = row.detailText {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(row.isUpcoming ? BrandColors.race : BrandColors.dim)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.distanceText).font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
                if let result = row.resultText {
                    Text(result).font(BrandFonts.number(15)).foregroundStyle(BrandColors.dim)
                }
            }
        }
        .glassCard()
        .contentShape(Rectangle())
    }
}
