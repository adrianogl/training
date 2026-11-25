import Foundation
import Insights
import Storage
import SwiftData
import Sync
import TrainingCore
import WorkoutAnalysis

struct WorkoutNoticeContent: Equatable, Sendable {
    let activityId: Int64
    let title: String
    let body: String
}

enum WorkoutNotice {
    private typealias C = WorkoutNoticeConstants

    static func status(activityId: Int64, in context: ModelContext) -> WorkoutNoticeStatus {
        let records = (try? context.fetch(FetchDescriptor<ActivityRecord>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
        guard let record = records.first(where: { $0.activityId == activityId && ActivityTypeKey.isRun($0.typeKey) }) else { return .waiting }
        guard ScoreReadiness.pending(record) == nil else { return .waiting }
        guard record.fitProcessed else { return .unavailable }
        let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
        guard let score = analysis.score?.value else { return .unavailable }
        let opening = WorkoutFeedback.summary(assessment: analysis.assessment, blocks: analysis.blocks, workoutName: record.workoutName).feedback.first
        let goals = (try? goalSnapshots(context: context, today: Day.today())) ?? []
        PersonalRecords.refreshEfforts(in: context)
        let highlights = PersonalRecords.timeline(PersonalRecords.runEfforts(records))[record.activityId] ?? .empty
        return .ready(content(record: record, score: score, opening: opening, goals: goals, records: highlights))
    }

    static func content(record: ActivityRecord, score: Int?, opening: String?, goals: [GoalSnapshot] = [], records: RunRecords = .empty) -> WorkoutNoticeContent {
        let name = record.workoutName.map(WorkoutTitle.clean) ?? (record.name.isEmpty ? C.fallbackName : record.name)
        let named = score.map { String(format: C.titleScoreFormat, name, $0) } ?? name
        var body = opening ?? stats(record)
        let goal = WorkoutNoticeGoals.evaluate(record: record, goals: goals)
        let met = goal?.metGoals ?? []
        let hits = records.records
        let title: String
        switch (hits.count, met.count) {
        case (0, 0):
            title = named
            if let note = goal?.note { body = body.isEmpty ? note : note + "\n" + body }
            if let near = records.near { body = joined(RecordText.near(near), body) }
        case (0, 1):
            title = String(format: C.metTitleFormat, met[0], named)
        case (1, 0):
            title = RecordText.title(hits[0]) + C.highlightSeparator + named
            body = joined(RecordText.body(hits[0]), body)
        default:
            title = RecordText.counts(records: hits.count, goals: met.count) + C.highlightSeparator + named
            body = joined(RecordText.summary(records: hits, goals: met), body)
        }
        return WorkoutNoticeContent(activityId: record.activityId, title: title, body: body)
    }

    private static func joined(_ highlight: String, _ body: String) -> String {
        body.isEmpty ? highlight : highlight + C.highlightBodySeparator + body
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
