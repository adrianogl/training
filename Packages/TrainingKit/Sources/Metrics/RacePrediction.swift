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
        if let current = best[effort.kind],
           !replaces(effort, predicted: predicted, current: current.effort, currentPredicted: current.predicted, target: distance) {
            continue
        }
        best[effort.kind] = (effort, predicted)
    }
    return best.values.map(\.effort).sorted { ($1.day, $0.kind.rawValue) < ($0.day, $1.kind.rawValue) }
}

private func replaces(_ effort: Effort, predicted: Double, current: Effort, currentPredicted: Double, target: Double) -> Bool {
    if effort.kind == .race {
        let gap = distanceGap(effort.distance, target)
        let currentGap = distanceGap(current.distance, target)
        let tolerance = RaceConstants.sameRaceDistanceLogTolerance
        if gap < currentGap - tolerance { return true }
        if gap > currentGap + tolerance { return false }
    }
    if predicted != currentPredicted { return predicted < currentPredicted }
    return current.day < effort.day
}

private func distanceGap(_ distance: Double, _ target: Double) -> Double {
    abs(log(distance / target))
}

private func predictionWeight(_ effort: Effort, on: Day) -> Double? {
    guard effort.distance > 0, effort.seconds > 0 else { return nil }
    let age = Double(effort.day.days(until: on))
    let window = effort.kind == .race ? RaceConstants.raceEffortWindowDays : RaceConstants.effortWindowDays
    guard age >= 0, age < window else { return nil }
    let weight = (RaceConstants.kindWeight[effort.kind] ?? 0) * (1 - age / window)
    return weight > 0 ? weight : nil
}

public func assessGoal(goalSeconds: Double, predictionSeconds: Double) -> GoalAssessment? {
    guard goalSeconds.isFinite, predictionSeconds.isFinite, goalSeconds > 0, predictionSeconds > 0 else { return nil }
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
