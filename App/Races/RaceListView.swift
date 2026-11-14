import Insights
import Storage
import SwiftData
import SwiftUI
import TrainingCore

struct RaceListView: View {
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<RaceRecord> { $0.deletedAt == nil }) private var races: [RaceRecord]
    @State private var model: RaceListModel?
    @State private var path: [RaceRoute] = []
    @State private var showsEditor = false
    @State private var openedDebugRace = false
    @State private var selection: RaceRoute?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var signature: [Date] {
        races.map(\.updatedAt).sorted()
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    listScroll
                        .frame(width: WorkoutConstants.listWidth)
                    Divider().overlay(BrandColors.line)
                    NavigationStack {
                        if let route = currentRoute {
                            destination(route)
                                .id(route)
                                .navigationDestination(for: Int64.self) { activityId in WorkoutDetailView(activityId: activityId) }
                        } else {
                            Text(RacesConstants.selectRace)
                                .foregroundStyle(BrandColors.dim)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(BrandBackground())
                        }
                    }
                }
            } else {
                NavigationStack(path: $path) {
                    listScroll
                        .navigationDestination(for: RaceRoute.self) { route in destination(route) }
                        .navigationDestination(for: Int64.self) { activityId in WorkoutDetailView(activityId: activityId) }
                }
            }
        }
        .sheet(isPresented: $showsEditor) {
            RaceEditorSheet(raceId: nil)
        }
        .task(id: signature) {
            await Task.yield()
            let loaded = RaceListModel(container: app.container, today: Day.today(), onChange: { app.remoteSync.scheduleSync() })
            await loaded.load()
            model = loaded
            openDebugRaceIfNeeded(loaded)
        }
    }

    private var listScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                CompactLogoHeader()
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
                            .background(BrandColors.accentFill, in: Circle())
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
        .toolbarVisibility(sizeClass == .regular ? .automatic : .hidden, for: .navigationBar)
    }

    private var currentRoute: RaceRoute? {
        if let selection { return selection }
        if let first = model?.upcoming.first { return .next(first.id) }
        return model?.completed.first.map { .completed($0.id) }
    }

    @ViewBuilder
    private func destination(_ route: RaceRoute) -> some View {
        switch route {
        case .next(let id):
            NextRaceView(raceId: id)
        case .completed(let id):
            if let model, let summary = model.summaries[id] {
                CompletedRaceView(summary: summary, model: model)
            }
        }
    }

    @ViewBuilder
    private func link(_ route: RaceRoute, _ row: RaceRowData) -> some View {
        if sizeClass == .regular {
            Button { selection = route } label: {
                RaceRow(row: row)
                    .overlay {
                        if currentRoute == route {
                            RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
                                .strokeBorder(BrandColors.accentFill, lineWidth: 2)
                        }
                    }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: route) { RaceRow(row: row) }
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func content(_ model: RaceListModel) -> some View {
        if model.upcoming.isEmpty && model.completed.isEmpty && model.candidates.isEmpty {
            Text(RacesConstants.emptyList)
                .font(.subheadline)
                .foregroundStyle(BrandColors.dim)
                .brandCard()
        }
        if !model.upcoming.isEmpty {
            SectionLabel(RacesConstants.upcomingTitle)
            ForEach(model.upcoming) { row in
                link(.next(row.id), row)
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
                link(.completed(row.id), row)
            }
        }
    }

    private func openDebugRaceIfNeeded(_ model: RaceListModel) {
        #if DEBUG
        guard !openedDebugRace, let target = UserDefaults.standard.string(forKey: AppConstants.openRaceDefaultsKey) else { return }
        openedDebugRace = true
        switch target {
        case "proxima":
            if let first = model.upcoming.first { path = [.next(first.id)]; selection = .next(first.id) }
        case "concluida":
            if let first = model.completed.first { path = [.completed(first.id)]; selection = .completed(first.id) }
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
                            .background(BrandColors.accentFill, in: Capsule())
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
        .brandCard()
        .contentShape(Rectangle())
    }
}
