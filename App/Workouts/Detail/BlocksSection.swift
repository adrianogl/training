import FITReader
import SwiftUI
import WorkoutAnalysis

struct BlocksSection: View {
    let blocks: [WorkoutBlock]
    let bars: [BlockBar]
    let kilometers: [Int: [WorkoutBlock]]
    let kilometerBars: [Int: [BlockBar]]
    let showsTarget: Bool
    @State private var expanded: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { position, block in
                row(position: position, block: block)
                ForEach(Array((kilometers[position] ?? []).enumerated()), id: \.offset) { index, kilometer in
                    let rowBars = kilometerBars[position] ?? []
                    line(kilometer, bar: rowBars.indices.contains(index) ? rowBars[index] : nil, indent: WorkoutDetailConstants.kilometerIndent)
                        .padding(.vertical, 5)
                }
                if position < blocks.count - 1 {
                    Divider().overlay(BrandColors.line)
                }
            }
            if showsTarget {
                legend.padding(.top, 10)
            }
        }
        .glassCard()
    }

    private func row(position: Int, block: WorkoutBlock) -> some View {
        let bar = bars.indices.contains(position) ? bars[position] : nil
        let canExpand = block.laps.count > 1 || (showsTarget && block.prescribed != nil)
        return VStack(alignment: .leading, spacing: 6) {
            line(block, bar: bar, indent: 0)
            if expanded.contains(position) {
                details(block)
            }
        }
        .padding(.vertical, 8)
        .opacity(block.status == .notExecuted ? 0.4 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canExpand else { return }
            withAnimation(.snappy) {
                if expanded.contains(position) { expanded.remove(position) } else { expanded.insert(position) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(canExpand ? .isButton : [])
    }

    private func line(_ block: WorkoutBlock, bar: BlockBar?, indent: CGFloat) -> some View {
        HStack(spacing: 8) {
            Text(shortLabel(block.label))
                .font(indent > 0 ? .caption : .footnote)
                .foregroundStyle(BrandColors.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.leading, indent)
                .frame(width: WorkoutDetailConstants.labelColumnWidth, alignment: .leading)
            BlockBarView(bar: bar, color: BrandColors.zone(block.dominantZone))
            Text(bar?.valueText ?? "—")
                .font(BrandFonts.number(indent > 0 ? 14 : 15))
                .foregroundStyle(indent > 0 ? BrandColors.dim : BrandColors.text)
                .frame(width: WorkoutDetailConstants.valueColumnWidth, alignment: .trailing)
            if showsTarget {
                Circle()
                    .fill(statusColor(block.status))
                    .frame(width: 8, height: 8)
                    .frame(width: WorkoutDetailConstants.dotColumnWidth)
            }
        }
    }

    private func details(_ block: WorkoutBlock) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsTarget, let step = block.prescribed {
                Text("Prescrito: \(prescription(step))")
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
            }
            ForEach(Array(block.laps.enumerated()), id: \.offset) { index, lap in
                HStack {
                    Text("\(index + 1)")
                        .foregroundStyle(BrandColors.dim)
                        .frame(width: 22, alignment: .leading)
                    Text(distance(lap.distance))
                    Spacer()
                    Text(WorkoutListModel.paceText(metersPerSecond: lap.avgSpeed ?? (lap.timerSeconds > 0 ? lap.distance / lap.timerSeconds : nil)) ?? "—")
                    Text(lap.avgHeartRate.map { "\($0) bpm" } ?? "—")
                        .frame(width: 64, alignment: .trailing)
                }
                .font(BrandFonts.number(14))
                .foregroundStyle(BrandColors.text)
            }
        }
        .padding(.leading, 4)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(BrandColors.band, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .frame(width: 14, height: 8)
                Text("faixa prescrita")
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(BrandColors.zones[4])
                    .frame(width: 14, height: 8)
                Text("o que você fez (cor = zona de FC)")
            }
        }
        .font(.caption2)
        .foregroundStyle(BrandColors.dim)
    }

    private func shortLabel(_ label: String) -> String {
        for (long, short) in WorkoutDetailConstants.shortLabels where label.hasPrefix(long) {
            return label.replacingOccurrences(of: long, with: short)
        }
        return label
    }

    private func statusColor(_ status: BlockStatus) -> Color {
        switch status {
        case .inTarget: BrandColors.accent
        case .faster, .slower, .aboveTarget, .belowTarget, .incomplete: BrandColors.race
        case .noTarget, .notExecuted: BrandColors.dim.opacity(0.5)
        }
    }

    private func prescription(_ step: PrescribedStep) -> String {
        let duration: String? = switch step.duration {
        case let .distance(meters): distance(meters)
        case let .time(seconds): WorkoutListModel.clockText(seconds)
        case .open, .repeatSteps: nil
        }
        let target: String? = switch step.target {
        case let .speed(low, high):
            range(
                low: WorkoutListModel.paceClock(metersPerSecond: high),
                high: WorkoutListModel.paceClock(metersPerSecond: low)
            ).map { "\($0) \(WorkoutConstants.paceUnit)" }
        case let .heartRateBpm(low, high): range(low: bound(low), high: bound(high)).map { "\($0) bpm" }
        case let .heartRatePercentMax(low, high): range(low: bound(low), high: bound(high)).map { "\($0)% da FC máx" }
        case let .heartRateZone(number): "Z\(number)"
        case .open: nil
        }
        return [duration, target].compactMap { $0 }.joined(separator: " · ").ifEmpty("livre")
    }

    private func bound(_ value: Int) -> String? {
        value > 0 ? "\(value)" : nil
    }

    private func range(low: String?, high: String?) -> String? {
        switch (low, high) {
        case let (low?, high?): "\(low)–\(high)"
        case let (low?, nil): "a partir de \(low)"
        case let (nil, high?): "até \(high)"
        case (nil, nil): nil
        }
    }

    private func distance(_ meters: Double) -> String {
        meters < WorkoutConstants.metersPerKilometer
            ? "\(Int(meters.rounded())) m"
            : WorkoutListModel.distanceText(meters)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
