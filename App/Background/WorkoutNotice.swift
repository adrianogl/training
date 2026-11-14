import Foundation
import Insights
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
        guard let record = records.first(where: { ActivityTypeKey.isRun($0.typeKey) && abs($0.start.timeIntervalSince(start)) <= C.matchTolerance }),
              record.fitProcessed else { return nil }
        let analysis = WorkoutAnalysisContext.build(record: record, records: records, in: context)
        guard let score = analysis.score?.value else { return nil }
        let opening = WorkoutFeedback.summary(assessment: analysis.assessment, blocks: analysis.blocks).feedback.first
        let goals = (try? goalSnapshots(context: context, today: Day.today())) ?? []
        return content(record: record, score: score, opening: opening, goals: goals)
    }

    static func content(record: ActivityRecord, score: Int?, opening: String?, goals: [GoalSnapshot] = []) -> WorkoutNoticeContent {
        let name = record.workoutName ?? (record.name.isEmpty ? C.fallbackName : record.name)
        var title = score.map { String(format: C.titleScoreFormat, name, $0) } ?? name
        var body = opening ?? stats(record)
        if let goal = WorkoutNoticeGoals.evaluate(record: record, goals: goals) {
            if let met = goal.metGoal { title = String(format: C.metTitleFormat, met, title) }
            if let note = goal.note { body = body.isEmpty ? note : note + "\n" + body }
        }
        return WorkoutNoticeContent(activityId: record.activityId, title: title, body: body)
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
