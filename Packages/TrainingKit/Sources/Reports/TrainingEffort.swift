import Metrics
import TrainingCore

private typealias C = TrainingEffortConstants

func trainingEffort(_ rule: TrainingEffortRule, sessions: [TrainingSession], today: Day) -> Effort? {
    let recent = sessions
        .filter { $0.day <= today && $0.day >= today.adding(days: -C.windowDays) && $0.work.meters >= rule.minimumMeters }
        .sorted { $0.day > $1.day }
        .prefix(C.sessions)
    guard let latest = recent.first, let pace = median(recent.map(\.work.pace)) else { return nil }
    let seconds = (pace + rule.paceOffset) * rule.distance / C.metersPerKilometer
    return Effort(distance: rule.distance, seconds: seconds, day: latest.day, kind: rule.effortKind)
}
