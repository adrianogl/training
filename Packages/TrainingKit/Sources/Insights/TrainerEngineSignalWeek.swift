import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    static func signalDecision(plan: TrainerPlan, closed: TrainerWeek, signals: [TrainerSignal]) -> TrainerSignalDecision? {
        guard let next = plan.weeks.first(where: { $0.index == closed.index + 1 }), !next.isRecovery, next.phase != .taper
        else { return nil }
        let strong = signals.count >= C.signalEarlyCount || (signals.contains(.hrv) && signals.contains(.restingHeartRate))
        if strong && canAnticipate(next, plan: plan) {
            let body = signals.filter(\.isBody).count
            return .early(body >= signals.count - body ? .body : .training)
        }
        return signals.count >= C.signalCalmCount ? .calm : nil
    }

    static func lightVolumeShare(_ kind: TrainerLightKind?) -> Double {
        switch kind {
        case .body: C.signalBodyVolumeShare
        case .training: C.signalTrainingVolumeShare
        case nil: C.recoveryVolumeShare
        }
    }

    static func weekStructure(_ structure: [Int: TrainerDayKind], week: TrainerWeek) -> [Int: TrainerDayKind] {
        let rotated = weekStructure(structure, index: week.index)
        guard let light = week.lightKind else { return rotated }
        return rotated.mapValues { kind in
            switch (light, kind) {
            case (.body, .vo2max), (.training, .threshold), (.training, .vo2max): .easy
            default: kind
            }
        }
    }

    private static func canAnticipate(_ week: TrainerWeek, plan: TrainerPlan) -> Bool {
        let last = plan.weeks.last { $0.isRecovery && $0.index < week.index }?.index ?? 0
        guard week.index - last >= C.signalEarlyMinimumGap else { return false }
        guard let race = plan.target.date else { return true }
        return week.start.days(until: race) > C.signalEarlyRaceDays
    }
}
