import Storage
import SwiftData
import SwiftUI

struct WorkoutListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \ActivityRecord.start, order: .reverse) private var records: [ActivityRecord]
    @State private var path: [Int64] = WorkoutListView.initialPath()
    @State private var selection: Int64? = WorkoutListView.initialPath().first

    var body: some View {
        let weeks = WorkoutListModel.weeks(records: records)
        Group {
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    list(weeks)
                        .frame(width: WorkoutConstants.listWidth)
                    Divider().overlay(BrandColors.line)
                    NavigationStack {
                        if let id = selection ?? weeks.first?.rows.first?.activityId {
                            WorkoutDetailView(activityId: id).id(id)
                        } else {
                            Text(WorkoutConstants.selectWorkout)
                                .foregroundStyle(BrandColors.dim)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(BrandBackground())
                        }
                    }
                }
            } else {
                NavigationStack(path: $path) {
                    list(weeks)
                        .navigationDestination(for: Int64.self) { activityId in
                            WorkoutDetailView(activityId: activityId)
                        }
                }
            }
        }
        .task {
            model.scoreRefresher.refresh()
        }
    }

    private func list(_ weeks: [WorkoutWeek]) -> some View {
        let current = selection ?? weeks.first?.rows.first?.activityId
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                CompactLogoHeader()
                Text(WorkoutConstants.listTitle)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(BrandColors.text)
                if case .running(let progress) = model.syncStatus {
                    ProgressView(value: progress) {
                        Text("Sincronizando com o Garmin")
                            .font(.caption)
                            .foregroundStyle(BrandColors.dim)
                    }
                }
                if weeks.isEmpty {
                    Text(WorkoutConstants.emptyList)
                        .foregroundStyle(BrandColors.dim)
                        .brandCard()
                }
                ForEach(weeks) { week in
                    HStack {
                        Text(WorkoutListModel.weekLabel(week.start))
                        Spacer()
                        Text(WorkoutListModel.weekSummary(week))
                    }
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                    .padding(.top, 8)
                    ForEach(week.rows) { row in
                        if sizeClass == .regular {
                            Button { selection = row.activityId } label: {
                                WorkoutRow(row: row, isSelected: row.activityId == current)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: row.activityId) {
                                WorkoutRow(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .refreshable { await model.syncNow(.pull) }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private static func initialPath(defaults: UserDefaults = .standard) -> [Int64] {
        #if DEBUG
        let activityId = defaults.object(forKey: AppConstants.openActivityDefaultsKey).flatMap { "\($0)" }.flatMap(Int64.init)
        return activityId.map { [$0] } ?? []
        #else
        return []
        #endif
    }
}
