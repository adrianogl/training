import Metrics
import TrainingCore

private typealias C = TrainingEffortConstants

private func recentSessions(_ sessions: [TrainingSession], minimumMeters: Double, today: Day) -> [TrainingSession] {
    Array(
        sessions
            .filter { $0.day <= today && $0.day >= today.adding(days: -C.windowDays) && $0.work.meters >= minimumMeters }
            .sorted { $0.day > $1.day }
            .prefix(C.sessions)
    )
}

func trainingEffort(_ rule: TrainingEffortRule, sessions: [TrainingSession], today: Day) -> Effort? {
    let recent = recentSessions(sessions, minimumMeters: rule.minimumMeters, today: today)
    guard let latest = recent.first, let pace = median(recent.map(\.work.pace)) else { return nil }
    let seconds = (pace + rule.paceOffset) * rule.distance / C.metersPerKilometer
    return Effort(distance: rule.distance, seconds: seconds, day: latest.day, kind: rule.effortKind)
}

public func thresholdWorkPace(_ sessions: [TrainingSession], on day: Day) -> Double? {
    median(recentSessions(sessions, minimumMeters: C.threshold.minimumMeters, today: day).map(\.work.pace))
}

public func thresholdRaceSeconds(workPace: Double, raceDistance: Double) -> Double {
    let rule = C.threshold
    let seconds = (workPace + rule.paceOffset) * rule.distance / C.metersPerKilometer
    return riegel(seconds: seconds, from: rule.distance, to: raceDistance)
}
