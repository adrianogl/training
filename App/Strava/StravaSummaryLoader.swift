import FITReader
import Foundation
import Insights
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

struct StravaPayload: Equatable, Sendable {
    let activityId: Int64
    let start: Date
    let elapsedSeconds: Double
    let distanceMeters: Double
    let text: String
    let scored: Bool
}

enum StravaSummaryLoader {
    private typealias C = StravaConstants

    static func payload(activityId: Int64, in context: ModelContext) -> StravaPayload? {
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        guard let record = records.first(where: { $0.activityId == activityId && ActivityTypeKey.isRun($0.typeKey) }),
              let meters = record.distance, meters > 0,
              let elapsed = record.duration ?? record.movingDuration, elapsed > 0
        else { return nil }
        let input = input(record: record, records: records, in: context)
        guard let text = StravaSummaryBuilder.text(input) else { return nil }
        return StravaPayload(activityId: activityId, start: record.start, elapsedSeconds: elapsed, distanceMeters: meters, text: text, scored: input.score != nil)
    }

    static func input(record: ActivityRecord, records: [ActivityRecord], in context: ModelContext) -> StravaSummaryInput {
        let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
        let kind = LastRunBuilder.kind(of: record)
        let steps = analysis.blocks
            .filter { $0.kind == .active && !$0.laps.isEmpty }
            .compactMap { block -> StravaBlockStep? in
                guard let prescribed = block.prescribed, let size = blockSize(prescribed.duration) else { return nil }
                return StravaBlockStep(set: prescribed.index, size: size)
            }
        let earliest = record.start.addingTimeInterval(-C.comparisonWindowDays * C.secondsPerDay)
        let similar = records
            .filter {
                ActivityTypeKey.isRun($0.typeKey) && $0.activityId != record.activityId
                    && $0.start < record.start && $0.start >= earliest && LastRunBuilder.kind(of: $0) == kind
            }
            .sorted { $0.start > $1.start }
            .map(similarRun)
        return StravaSummaryInput(
            kind: kind,
            goalPace: isGoalPace(record),
            steps: steps,
            workPace: WorkoutAnalysis.workPace(blocks: analysis.blocks)?.pace,
            kilometers: (record.distance ?? 0) / WorkoutConstants.metersPerKilometer,
            paceSeconds: LastRunBuilder.paceSeconds(record),
            heartRate: record.averageHR,
            score: record.scoreValue ?? analysis.score?.value,
            fadeKm: detailedAnalysis(record: record, history: records, daily: [])?.fadeKm,
            similar: similar
        )
    }

    static func blockSize(_ duration: StepDuration) -> String? {
        guard case .distance(let meters) = duration else { return BlockNaming.durationText(duration) }
        guard meters >= WorkoutConstants.metersPerKilometer else { return "\(Int(meters.rounded())) m" }
        let kilometers = meters / WorkoutConstants.metersPerKilometer
        return kilometers.rounded() == kilometers ? "\(Int(kilometers)) km" : "\(WorkoutFormat.kilometers(meters)) km"
    }

    private static func similarRun(_ record: ActivityRecord) -> StravaSimilar {
        StravaSimilar(
            dateText: LastRunBuilder.shortDate(record.start),
            workPace: WorkoutAnalysis.workPace(record)?.pace,
            kilometers: (record.distance ?? 0) / WorkoutConstants.metersPerKilometer,
            paceSeconds: LastRunBuilder.paceSeconds(record),
            heartRate: record.averageHR
        )
    }

    private static func isGoalPace(_ record: ActivityRecord) -> Bool {
        let name = (record.workoutName ?? record.name).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        return C.goalPaceWords.contains { name.contains($0) }
    }
}
