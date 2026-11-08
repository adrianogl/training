import Foundation
import TrainingCore

public func riegel(seconds: Double, from: Double, to: Double, exponent: Double = 1.06) -> Double {
    seconds * pow(to / from, exponent)
}

public func predict(distance: Double, efforts: [Effort], on: Day) -> Double? {
    var weighted = 0.0
    var totalWeight = 0.0
    for effort in bestEfforts(efforts, for: distance, on: on) {
        guard let weight = predictionWeight(effort, on: on) else { continue }
        weighted += weight * riegel(seconds: effort.seconds, from: effort.distance, to: distance)
        totalWeight += weight
    }
    return totalWeight > 0 ? weighted / totalWeight : nil
}

public func bestEfforts(_ efforts: [Effort], for distance: Double, on: Day) -> [Effort] {
    var best: [EffortKind: (effort: Effort, predicted: Double)] = [:]
    for effort in efforts where predictionWeight(effort, on: on) != nil {
        let predicted = riegel(seconds: effort.seconds, from: effort.distance, to: distance)
        if let current = best[effort.kind] {
            let faster = predicted < current.predicted
            let tieButNewer = predicted == current.predicted && current.effort.day < effort.day
            guard faster || tieButNewer else { continue }
        }
        best[effort.kind] = (effort, predicted)
    }
    return best.values.map(\.effort).sorted { ($1.day, $0.kind.rawValue) < ($0.day, $1.kind.rawValue) }
}

private func predictionWeight(_ effort: Effort, on: Day) -> Double? {
    guard effort.distance > 0, effort.seconds > 0 else { return nil }
    let age = Double(effort.day.days(until: on))
    guard age >= 0, age < RaceConstants.effortWindowDays else { return nil }
    let weight = (RaceConstants.kindWeight[effort.kind] ?? 0) * (1 - age / RaceConstants.effortWindowDays)
    return weight > 0 ? weight : nil
}

public func assessGoal(goalSeconds: Double, predictionSeconds: Double) -> GoalAssessment {
    let gap = (predictionSeconds - goalSeconds) / predictionSeconds
    if gap > RaceConstants.aggressiveGap { return .aggressive }
    if gap > RaceConstants.challengingGap { return .challenging }
    return .easy
}

public func longRunTarget(raceDistance: Double) -> Double {
    if raceDistance <= RaceConstants.shortRaceLimit { return raceDistance }
    if raceDistance <= RaceConstants.halfRaceLimit { return raceDistance * RaceConstants.halfLongRunShare }
    return raceDistance * RaceConstants.fullLongRunShare
}
