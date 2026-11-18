import Insights
import SwiftUI

struct TrainerRecentRaceCard: View {
    @Binding var overrides: [TrainerPaceKind: Double]
    @State private var meters = TrainerRecentRaceConstants.distances[0].meters
    @State private var minutes = TrainerRecentRaceConstants.defaultMinutes
    @State private var seconds = 0

    private typealias C = TrainerRecentRaceConstants

    var body: some View {
        DSNotice(tone: .info, title: C.title, text: C.text) {
            VStack(alignment: .leading, spacing: DSSpacing.s2) {
                Picker(C.distanceLabel, selection: $meters) {
                    ForEach(C.distances, id: \.meters) { Text($0.title).tag($0.meters) }
                }
                .pickerStyle(.segmented)
                HStack(spacing: DSSpacing.s2) {
                    Stepper(value: $minutes, in: C.minuteRange) {
                        Text(String(format: C.timeFormat, minutes, seconds)).font(BrandFonts.number(20)).foregroundStyle(BrandColors.text)
                    }
                }
                Stepper(C.secondsLabel, value: $seconds, in: 0...55, step: 5)
                    .font(.footnote)
                Button(overrides.isEmpty ? C.apply : C.applied) {
                    overrides = TrainerEngine.pacesFromRecentRace(meters: meters, seconds: Double(minutes * 60 + seconds))
                }
                .buttonStyle(.ds(.secondary))
            }
        }
    }
}
