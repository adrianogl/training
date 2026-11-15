import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants
private typealias T = TrainerEngineText

extension TrainerEngine {
    static func describe(_ workout: TrainerWorkout) -> String {
        guard workout.kind != .off else { return T.offTitle }
        let pace = workout.paceLow.flatMap { low in workout.paceHigh.map { T.paceRange(low, $0) } }
        let suffix = pace.map { " a \($0)" } ?? ""
        let main = workout.steps.filter { $0.kind == .work && $0.method != .repetition }
        if workout.kind == .threshold || workout.kind == .vo2max, !main.isEmpty {
            let recovery = workout.steps.first(where: { $0.kind == .recovery }).map { step in
                step.restSeconds.map { ", \(T.restSummary($0))" } ?? ", rec. \(Int(step.meters)) m"
            } ?? ""
            let blocks = main.map { TrainerQualityBlock(repeats: $0.repeats, meters: $0.meters) }
            let label = blocks.count == 1 ? "\(blocks[0].repeats) × \(T.distance(blocks[0].meters))" : T.sessionLabel(blocks)
            return "\(label)\(suffix)\(recovery)"
        }
        return "\(T.kilometers(workout.totalMeters))\(suffix)"
    }

    static func sameContent(_ old: TrainerWorkout, _ new: TrainerWorkout) -> Bool {
        let low = abs((old.paceLow ?? 0) - (new.paceLow ?? 0))
        let high = abs((old.paceHigh ?? 0) - (new.paceHigh ?? 0))
        let sameRest = old.steps.map(\.restSeconds) == new.steps.map(\.restSeconds)
        return old.title == new.title && old.totalMeters == new.totalMeters && old.note == new.note && sameRest
            && low < C.paceChangeSeconds && high < C.paceChangeSeconds
    }

    static func changeTitle(_ workout: TrainerWorkout) -> String {
        "\(T.kindName(workout.kind)) de \(T.weekdayName(workout.day)), \(workout.day.day)"
    }

    static func legsAffected(_ workout: TrainerWorkout) -> Bool {
        switch workout.kind {
        case .threshold, .vo2max: workout.note != nil
        case .long: workout.steps.count > 1
        default: false
        }
    }

    static func describeChange(_ old: TrainerWorkout, _ new: TrainerWorkout) -> (before: String, after: String) {
        let before = describe(old)
        let after = describe(new)
        guard before == after, old.note != new.note else { return (before, after) }
        return (old.note ?? T.noNote, new.note ?? T.noNote)
    }

    static func reason(old: TrainerWorkout, new: TrainerWorkout, reasons: TrainerChangeReasons) -> String {
        if reasons.strength { return legsAffected(new) ? new.rationale : T.strengthLifted }
        if reasons.requests.contains(where: { $0.contains(new.day) }) { return new.rationale }
        let kind = new.kind == .off ? old.kind : new.kind
        if kind == .long, let text = reasons.long { return text }
        if let text = reasons.quality[kind] { return text }
        if old.title == new.title && old.totalMeters == new.totalMeters { return T.paceReason }
        if let text = reasons.volume { return text }
        return T.skeletonFallback
    }

    static func workoutChanges(
        old: [TrainerWorkout], new: [TrainerWorkout], reasons: TrainerChangeReasons
    ) -> [TrainerChange] {
        let oldByDay = Dictionary(old.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let newByDay = Dictionary(new.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        var changes: [TrainerChange] = []
        var handled: Set<Day> = []
        for workout in new.sorted(by: { $0.day < $1.day }) where [.threshold, .vo2max, .long].contains(workout.kind) {
            guard oldByDay[workout.day]?.title != workout.title,
                  let source = old.first(where: {
                      $0.title == workout.title && $0.day != workout.day && newByDay[$0.day]?.title != workout.title
                  }),
                  reasons.requests.contains(where: { $0.contains(workout.day) || $0.contains(source.day) }) else { continue }
            handled.insert(workout.day)
            changes.append(TrainerChange(
                kind: .moved, day: workout.day, title: changeTitle(workout),
                before: "\(T.dayLabel(source.day)): \(describe(source))", after: "\(T.dayLabel(workout.day)): \(describe(workout))",
                reason: workout.rationale
            ))
        }
        for workout in new.sorted(by: { $0.day < $1.day }) where !handled.contains(workout.day) {
            guard let previous = oldByDay[workout.day], !sameContent(previous, workout) else { continue }
            let kind: TrainerChangeKind
            if previous.kind == .off && workout.kind != .off {
                kind = .added
            } else if previous.kind != .off && workout.kind == .off {
                kind = .removed
            } else {
                kind = .changed
            }
            let text = describeChange(previous, workout)
            changes.append(TrainerChange(
                kind: kind, day: workout.day, title: changeTitle(kind == .removed ? previous : workout),
                before: text.before, after: text.after, reason: reason(old: previous, new: workout, reasons: reasons)
            ))
        }
        return changes.sorted { ($0.day?.iso ?? "") < ($1.day?.iso ?? "") }
    }

    static func skeletonChange(old: [TrainerWeek], new: [TrainerWeek], reasons: TrainerChangeReasons, held: Bool) -> TrainerChange? {
        let differing = new.filter { week in
            guard let before = old.first(where: { $0.index == week.index }) else { return false }
            return before.plannedMeters != week.plannedMeters || before.longMeters != week.longMeters
        }
        guard let first = differing.first, let last = differing.last,
              let before = old.first(where: { $0.index == first.index }) else { return nil }
        var text = reasons.long ?? reasons.volume ?? T.skeletonFallback
        if differing.count > 1 && held { text = T.skeletonLater(text) }
        return TrainerChange(
            kind: .skeleton, weekIndex: first.index, title: T.skeletonTitle(first: first.index, last: last.index),
            before: T.skeletonSummary(before), after: T.skeletonSummary(first), reason: text
        )
    }

    static func newWeekChanges(
        oldEnd: Day?, new: [TrainerWorkout], weeks: [TrainerWeek]
    ) -> [TrainerChange] {
        let added = new.filter { workout in oldEnd.map { workout.day > $0 } ?? true }
        let grouped = Dictionary(grouping: added) { $0.day.weekStart }
        return grouped.keys.sorted().compactMap { start in
            guard let week = weeks.first(where: { $0.start == start }), let items = grouped[start] else { return nil }
            let meters = items.reduce(0.0) { $0 + $1.totalMeters }
            let count = items.filter { $0.kind != .off }.count
            return TrainerChange(
                kind: .newWeek, weekIndex: week.index, title: T.newWeek(week.index),
                after: T.skeletonSummary(week), reason: T.newWeekReason(count: count, meters: meters)
            )
        }
    }
}
