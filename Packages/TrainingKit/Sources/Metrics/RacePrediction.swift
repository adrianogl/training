import Foundation
import TrainingCore

public func riegel(seconds: Double, from: Double, to: Double, exponent: Double = 1.06) -> Double {
    seconds * pow(to / from, exponent)
}

public func predict(distance: Double, efforts: [Effort], on: Day) -> Double? {
    var weighted = 0.0
    var totalWeight = 0.0
    for effort in efforts where effort.distance > 0 {
        let age = Double(effort.day.days(until: on))
        guard age >= 0, age <= RaceConstants.effortWindowDays else { continue }
        let weight = (RaceConstants.kindWeight[effort.kind] ?? 0) * (1 - age / RaceConstants.effortWindowDays)
        guard weight > 0 else { continue }
        weighted += weight * riegel(seconds: effort.seconds, from: effort.distance, to: distance)
        totalWeight += weight
    }
    return totalWeight > 0 ? weighted / totalWeight : nil
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
