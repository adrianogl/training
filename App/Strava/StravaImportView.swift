import RemoteSync
import SwiftUI

struct StravaImportView: View {
    let model: StravaModel
    @State private var runs: [StravaRunCandidate] = []
    @State private var state = StravaImportState.loading

    private typealias T = StravaImportText

    var body: some View {
        Form {
            Section {
                Text(T.intro).font(.footnote).foregroundStyle(BrandColors.dim)
                switch state {
                case .loading:
                    HStack(spacing: 8) { ProgressView(); Text(T.loading).foregroundStyle(BrandColors.dim) }
                case .failed(let message):
                    Text(message).font(.footnote).foregroundStyle(BrandColors.attention)
                case .ready where runs.isEmpty:
                    Text(T.empty).foregroundStyle(BrandColors.dim)
                case .ready:
                    ForEach(runs) { run in row(run) }
                }
            } footer: {
                Text(T.pending)
            }
        }
        .navigationTitle(T.title)
        .task { await load() }
        .refreshable { await load() }
    }

    private func row(_ run: StravaRunCandidate) -> some View {
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
}
