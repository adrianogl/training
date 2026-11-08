import Storage
import SwiftData
import SwiftUI

struct WorkoutListView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \ActivityRecord.start, order: .reverse) private var records: [ActivityRecord]
    @State private var filter: WorkoutFilter = .all

    var body: some View {
        let rows = WorkoutListModel.rows(filter: filter, records: records)
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Logo(showsTagline: true)
                        .padding(.vertical, 8)
                    Picker("Filtro", selection: $filter) {
                        ForEach(WorkoutFilter.allCases, id: \.self) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 6)
                    if case .running(let progress) = model.syncStatus {
                        ProgressView(value: progress) {
                            Text("Sincronizando com o Garmin")
                                .font(.caption)
                                .foregroundStyle(BrandColors.dim)
                        }
                    }
                    if rows.isEmpty {
                        Text("Nenhum treino neste filtro.")
                            .foregroundStyle(BrandColors.dim)
                            .glassCard()
                    }
                    ForEach(rows) { row in
                        NavigationLink(value: row) {
                            WorkoutRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .refreshable { await model.syncNow(.launch) }
            .navigationDestination(for: WorkoutRowData.self) { row in
                WorkoutDetailPlaceholder(row: row)
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
    }
}
