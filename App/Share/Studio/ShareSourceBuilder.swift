import FITReader
import Foundation
import WorkoutAnalysis

enum ShareSourceBuilder {
    private typealias C = ShareStudioConstants

    static func source(
        input: WorkoutShareInput,
        route: [Coordinate],
        samples: [FITSample],
        zoneFloors: [Int],
        blocks: [WorkoutBlock],
        comparisonRows: [ComparisonRow],
        analysis: WorkoutAnalysisSummary
    ) -> ShareSource {
        let series = seriesBars(blocks)
        return ShareSource(
            input: input,
            track: ShareTrackBuilder.track(route: route, samples: samples),
            zoneFloors: zoneFloors,
            series: series,
            seriesTitle: BlockNaming.sections(blocks).first { $0.positions.contains { blocks[$0].kind == .active } }?.title,
            seriesSummary: seriesSummary(series),
            evolution: evolution(comparisonRows),
            feedbackLine: analysis.entries.first { $0.tag == .good }?.title ?? analysis.feedback.first
        )
    }

    static func seriesBars(_ blocks: [WorkoutBlock]) -> [SeriesBar] {
        blocks.compactMap { block in
            guard block.kind == .active, block.distance > 0, block.seconds > 0,
                  case let .speed(low, high)? = block.prescribed?.target else { return nil }
            return SeriesBar(
                label: "\(block.ordinal)º",
                pace: block.seconds / (block.distance / WorkoutConstants.metersPerKilometer),
                zone: block.dominantZone,
                inTarget: block.status == .inTarget,
                fastest: high > 0 ? WorkoutConstants.metersPerKilometer / high : nil,
                slowest: low > 0 ? WorkoutConstants.metersPerKilometer / low : nil
            )
        }
    }

    static func evolution(_ rows: [ComparisonRow]) -> [EvolutionPoint] {
        rows.reversed().compactMap { row in
            row.secondsPerKilometer.map { EvolutionPoint(label: row.dateText, pace: $0, heartRate: row.heartRate, isCurrent: row.isCurrent) }
        }
    }

    private static func seriesSummary(_ bars: [SeriesBar]) -> String? {
        guard let fastest = bars.compactMap(\.fastest).min(), let slowest = bars.compactMap(\.slowest).max() else { return nil }
        return String(format: C.seriesTargetFormat, WorkoutFormat.clock(fastest), WorkoutFormat.clock(slowest)) + C.paceUnit
    }
}
