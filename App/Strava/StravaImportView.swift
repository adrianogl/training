import RemoteSync
import SwiftUI

struct StravaImportView: View {
    let model: StravaModel
    @State private var runs: [StravaRunCandidate] = []
    @State private var state = StravaImportState.loading
    @State private var working: Set<Int64> = []
    @State private var feedback: String?

    private typealias T = StravaImportText

    var body: some View {
        Form {
            Section {
                Text(T.intro).font(.footnote).foregroundStyle(BrandColors.dim)
                switch state {
                case .loading:
                    DSLoadingState(title: T.loading)
                case .failed(let message):
                    DSErrorState(title: T.failedTitle, text: message) { Task { await load() } }
                case .ready where runs.isEmpty:
                    DSEmptyState(symbol: T.emptySymbol, title: T.emptyTitle, text: T.empty)
                case .ready:
                    ForEach(runs) { run in row(run) }
                }
                if let feedback {
                    Text(feedback).font(.footnote).foregroundStyle(BrandColors.dim)
                }
            } footer: {
                Text(T.footer)
            }
            if state == .ready, runs.count > 1 {
                Section {
                    Button(T.importAll(runs.count)) { Task { await importRuns(runs) } }
                        .disabled(!working.isEmpty)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BrandBackground())
        .navigationTitle(T.title)
        .toolbarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func row(_ run: StravaRunCandidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(T.runTitle(run)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Spacer()
                    Text(T.distance(run)).font(.subheadline).foregroundStyle(BrandColors.text).monospacedDigit()
                }
                HStack(spacing: 4) {
                    ForEach(Array(T.detail(run).enumerated()), id: \.offset) { index, part in
                        if index > 0 { Text("·").foregroundStyle(BrandColors.dim) }
                        Text(part).foregroundStyle(part == T.noHeartRate ? BrandColors.attention : BrandColors.dim)
                    }
                }
                .font(.footnote)
                .monospacedDigit()
            }
            HStack(spacing: 8) {
                if working.contains(run.id) {
                    ProgressView()
                    Text(T.importing).font(.footnote).foregroundStyle(BrandColors.dim)
                } else {
                    Button(T.importButton) { Task { await importRuns([run]) } }
                        .buttonStyle(.ds(.primary))
                    Button(T.ignoreButton) { Task { await ignore(run) } }
                        .buttonStyle(.ds(.secondary))
                }
            }
            .disabled(!working.isEmpty && !working.contains(run.id))
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        state = .loading
        do {
            runs = try await model.runCandidates()
            state = .ready
        } catch StravaLinkError.retryLater {
            state = .failed(T.retryLater)
        } catch {
            state = .failed(T.failed)
        }
    }

    private func importRuns(_ selected: [StravaRunCandidate]) async {
        working = Set(selected.map(\.id))
        defer { working = [] }
        do {
            let count = try await model.importRuns(selected)
            feedback = T.imported(count)
        } catch StravaLinkError.retryLater {
            feedback = T.retryLater
        } catch {
            feedback = T.failed
        }
        if let fresh = try? await model.runCandidates() { runs = fresh }
    }

    private func ignore(_ run: StravaRunCandidate) async {
        await model.ignore([run.id])
        runs.removeAll { $0.id == run.id }
    }
}
