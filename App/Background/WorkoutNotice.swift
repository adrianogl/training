import Foundation
import Storage
import SwiftData
import TrainingCore
import WorkoutAnalysis

struct WorkoutNoticeContent: Equatable, Sendable {
    let activityId: Int64
    let title: String
    let body: String
}

enum WorkoutNotice {
    private typealias C = WorkoutNoticeConstants

    static func content(start: Date, in context: ModelContext) -> WorkoutNoticeContent? {
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        guard let record = records.first(where: { ActivityTypeKey.isRun($0.typeKey) && abs($0.start.timeIntervalSince(start)) <= C.matchTolerance }) else { return nil }
        let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
        let opening = WorkoutFeedback.summary(assessment: analysis.assessment, blocks: analysis.blocks).feedback.first
        return content(record: record, score: analysis.score?.value, opening: opening)
    }

    static func content(record: ActivityRecord, score: Int?, opening: String?) -> WorkoutNoticeContent {
        let name = record.workoutName ?? (record.name.isEmpty ? C.fallbackName : record.name)
        let title = score.map { String(format: C.titleScoreFormat, name, $0) } ?? name
        return WorkoutNoticeContent(activityId: record.activityId, title: title, body: opening ?? stats(record))
    }

    static func stats(_ record: ActivityRecord) -> String {
        guard let meters = record.distance, meters > 0 else { return "" }
        let kilometers = meters / WorkoutConstants.metersPerKilometer
        let seconds = record.movingDuration ?? record.duration ?? 0
        var text = String(format: C.statsFormat, TodayText.decimal(kilometers, fractionDigits: 1), WorkoutFormat.clock(seconds / kilometers))
        if let heart = record.averageHR { text += String(format: C.heartRateFormat, Int(heart.rounded())) }
        return text
    }
}
