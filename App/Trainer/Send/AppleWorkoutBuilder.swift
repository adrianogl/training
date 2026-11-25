import Foundation
import GarminAPI
import HealthKit
import TrainingCore
import WorkoutKit

enum AppleWorkoutBuilder {
    static func plan(_ item: TrainerSendItem) -> WorkoutPlan? {
        switch item.kind {
        case .run: run(item).map { WorkoutPlan(.custom($0)) }
        case .strength: strength(item).map { WorkoutPlan(.goal($0)) }
        }
    }

    static func run(_ item: TrainerSendItem) -> CustomWorkout? {
        guard !item.runSteps.isEmpty else { return nil }
        var steps = item.runSteps
        var warmup: WorkoutStep?
        var cooldown: WorkoutStep?
        if case .warmup(let meters, _, _, _) = steps.first {
            warmup = WorkoutStep(goal: .distance(meters, .meters))
            steps.removeFirst()
        }
        if case .cooldown(let meters, _, _, _) = steps.last {
            cooldown = WorkoutStep(goal: .distance(meters, .meters))
            steps.removeLast()
        }
        let blocks = steps.compactMap(block)
        return CustomWorkout(activity: .running, location: .outdoor, displayName: item.title, warmup: warmup, blocks: blocks, cooldown: cooldown)
    }

    static func strength(_ item: TrainerSendItem) -> SingleGoalWorkout? {
        guard let seconds = item.strengthSeconds, seconds > 0 else { return nil }
        let minutes = (seconds / 60).rounded(.up)
        return SingleGoalWorkout(activity: .traditionalStrengthTraining, location: .indoor, goal: .time(minutes, .minutes))
    }

    static func block(_ step: PlannedRunStep) -> IntervalBlock? {
        switch step {
        case .repeated(let times, let inner):
            let steps = inner.compactMap(interval)
            return steps.isEmpty ? nil : IntervalBlock(steps: steps, iterations: max(times, 1))
        default:
            return interval(step).map { IntervalBlock(steps: [$0], iterations: 1) }
        }
    }

    static func interval(_ step: PlannedRunStep) -> IntervalStep? {
        switch step {
        case .interval(let meters, let fastest, let slowest, _):
            return IntervalStep(.work, goal: .distance(meters, .meters), alert: paceAlert(fastest: fastest, slowest: slowest))
        case .recovery(let meters), .warmup(let meters, _, _, _), .cooldown(let meters, _, _, _):
            return IntervalStep(.recovery, goal: .distance(meters, .meters))
        case .rest(let seconds):
            return IntervalStep(.recovery, goal: .time(seconds, .seconds))
        case .repeated:
            return nil
        }
    }

    static func paceAlert(fastest: Double?, slowest: Double?) -> SpeedRangeAlert? {
        guard let fastest, let slowest, fastest > 0, slowest >= fastest else { return nil }
        return .speed((1000 / slowest)...(1000 / fastest), unit: .metersPerSecond)
    }

    static func date(_ day: Day) -> DateComponents {
        DateComponents(year: day.year, month: day.month, day: day.day, hour: TrainerSendConstants.scheduledHour)
    }

    static func id(_ plan: WorkoutPlan) -> Int64 {
        let bytes = withUnsafeBytes(of: plan.id.uuid) { Array($0.prefix(8)) }
        return Int64(bitPattern: bytes.reduce(UInt64(0)) { $0 << 8 | UInt64($1) })
    }
}

@MainActor
enum AppleWorkoutSender {
    static func send(_ items: [TrainerSendItem], stale: [(key: String, record: TrainerSentRecord)], store: TrainerSendStore) async -> TrainerSendResult {
        let scheduler = WorkoutScheduler.shared
        _ = await scheduler.requestAuthorization()
        return await TrainerSender.send(
            items, stale: stale, store: store,
            create: { item in
                guard let plan = AppleWorkoutBuilder.plan(item) else { throw AppleWorkoutError.unsupported }
                await scheduler.schedule(plan, at: AppleWorkoutBuilder.date(item.day))
                return AppleWorkoutBuilder.id(plan)
            },
            remove: { id in
                for scheduled in await scheduler.scheduledWorkouts where AppleWorkoutBuilder.id(scheduled.plan) == id {
                    await scheduler.remove(scheduled.plan, at: scheduled.date)
                }
            }
        )
    }
}

enum AppleWorkoutError: Error {
    case unsupported
}
