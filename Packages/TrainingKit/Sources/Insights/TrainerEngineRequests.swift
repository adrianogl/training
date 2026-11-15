import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    public static func classify(requestText: String) -> TrainerRequestCategory {
        let normalized = requestText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let words = normalized.split { !$0.isLetter }.map(String.init)
        func matches(_ list: TrainerEngineConstants.Words) -> Bool {
            list.phrases.contains { normalized.contains($0) }
                || words.contains { word in list.exact.contains(word) || list.prefixes.contains { word.hasPrefix($0) } }
        }
        if matches(C.travelWords) { return .travel }
        if matches(C.painWords) { return .pain }
        if matches(C.fatigueWords) { return .fatigue }
        if matches(C.moreTimeWords) { return .moreTime }
        if matches(C.goalWords) { return .goalChanged }
        return .other
    }

    static func end(of request: TrainerRequest) -> Day {
        if let until = request.until { return max(until, request.from) }
        let days: Int = switch request.category {
        case .travel: C.travelPeriodDays
        case .pain: C.painPeriodDays
        default: C.moreTimePeriodDays
        }
        return request.from.adding(days: days - 1)
    }

    static func activeRequests(of plan: TrainerPlan, today: Day) -> [TrainerRequest] {
        plan.versions.compactMap { version -> TrainerRequest? in
            guard case .request(let request) = version.trigger, shapesDetail(request.category) else { return nil }
            return end(of: request) >= today ? request : nil
        }
    }

    static func shapesDetail(_ category: TrainerRequestCategory) -> Bool {
        category == .travel || category == .pain || category == .moreTime
    }

    static func applying(
        _ requests: [TrainerRequest], to workouts: [TrainerWorkout], paces: TrainerPaces, today: Day
    ) -> [TrainerWorkout] {
        var result = workouts
        for request in requests {
            switch request.category {
            case .travel: applyTravel(request, to: &result, paces: paces, today: today)
            case .pain: applyPain(request, to: &result, paces: paces)
            case .moreTime: applyMoreTime(request, to: &result, paces: paces)
            default: break
            }
        }
        return result
    }

    private static let replaceable: [TrainerDayKind] = [.easy, .optionalEasy, .off]

    private static func applyTravel(_ request: TrainerRequest, to workouts: inout [TrainerWorkout], paces: TrainerPaces, today: Day) {
        let until = end(of: request)
        let period = request.from...until
        for workout in workouts where period.contains(workout.day) && (workout.kind == .threshold || workout.kind == .vo2max) {
            let candidates = (1...C.detailDays).map { request.from.adding(days: -$0) }.filter { $0 >= today }
            let destination = candidates.first { day in
                workouts.contains { $0.day == day && replaceable.contains($0.kind) }
            }
            guard let destination, let at = workouts.firstIndex(where: { $0.day == destination }),
                  let from = workouts.firstIndex(where: { $0.day == workout.day }) else {
                replace(workout.day, in: &workouts, with: travelEasy(workout.day, request, until, paces))
                continue
            }
            var moved = workout
            moved.day = destination
            moved.rationale = T.travelMoved(workout.title, from: request.from, to: destination, until: until)
            workouts[at] = moved
            workouts[from] = offWorkout(day: workout.day, rationale: T.travelVacated(from: request.from, until: until))
        }
        for workout in workouts where period.contains(workout.day) && workout.kind == .long {
            replace(workout.day, in: &workouts, with: travelEasy(workout.day, request, until, paces))
            let returning = (1...C.returnSearchDays).map { until.adding(days: $0) }
            guard let day = returning.first(where: { day in workouts.contains { $0.day == day && replaceable.contains($0.kind) } }),
                  let at = workouts.firstIndex(where: { $0.day == day }) else { continue }
            var back = workout
            back.day = day
            back.rationale = T.travelLongReturn(from: request.from, until: until, to: day)
            workouts[at] = back
        }
    }

    private static func travelEasy(_ day: Day, _ request: TrainerRequest, _ until: Day, _ paces: TrainerPaces) -> TrainerWorkout {
        easyWorkout(day: day, meters: C.travelRunMeters, paces: paces, rationale: T.travelDropped(from: request.from, until: until))
    }

    private static func replace(_ day: Day, in workouts: inout [TrainerWorkout], with workout: TrainerWorkout) {
        if let index = workouts.firstIndex(where: { $0.day == day }) { workouts[index] = workout }
    }

    private static func applyPain(_ request: TrainerRequest, to workouts: inout [TrainerWorkout], paces: TrainerPaces) {
        let until = end(of: request)
        let reason = T.painReason(from: request.from, until: until)
        for index in workouts.indices where (request.from...until).contains(workouts[index].day) {
            let workout = workouts[index]
            switch workout.kind {
            case .threshold, .vo2max:
                workouts[index] = easyWorkout(day: workout.day, meters: C.painQualityMeters, paces: paces, rationale: reason)
            case .easy, .optionalEasy, .long:
                let meters = max(C.painMinimumMeters, roundKilometers(workout.totalMeters * C.painScale))
                let isLong = workout.kind == .long
                workouts[index] = steadyWorkout(
                    day: workout.day, kind: workout.kind, meters: meters, pace: isLong ? paces.long : paces.easy,
                    band: C.easyBand, title: T.title(kind: workout.kind, meters: meters), note: workout.note, rationale: reason
                )
            case .off, .race:
                break
            }
        }
    }

    private static func applyMoreTime(_ request: TrainerRequest, to workouts: inout [TrainerWorkout], paces: TrainerPaces) {
        let until = end(of: request)
        for index in workouts.indices
        where workouts[index].kind == .optionalEasy && (request.from...until).contains(workouts[index].day) {
            workouts[index] = easyWorkout(
                day: workouts[index].day, meters: C.moreTimeMeters, paces: paces,
                rationale: T.moreTimeReason(from: request.from, until: until)
            )
        }
    }
}
