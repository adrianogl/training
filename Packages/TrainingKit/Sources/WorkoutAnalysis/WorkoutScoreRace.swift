import Foundation

public func scoreRace(_ race: RaceScoreInput, blocks: [WorkoutBlock], splits: [WorkoutBlock], previous: [WorkoutOccurrence]) -> WorkoutScore? {
    var cost = costItem(blocks, previous: previous, hasHeartRate: blocks.contains { $0.avgHeartRate != nil })
    cost.reason = cost.reason.map(raceCostReason)
    return combinedScore([raceExecutionItem(race), raceIntentItem(race, splits: splits), cost])
}

private func raceCostReason(_ reason: ScoreReason) -> ScoreReason {
    switch reason {
    case .noHistory: .noPreviousRace
    case .lessEfficient: .lessEfficientThanRaces
    case .moreEfficient: .moreEfficientThanRaces
    default: reason
    }
}

private func raceExecutionItem(_ race: RaceScoreInput) -> ScoreItem {
    guard let targetPace = race.targetPace else { return absent(.execution, .noRaceTarget) }
    guard let distance = race.distance, distance > 0, let seconds = race.seconds, seconds > 0 else { return absent(.execution, .noSplits) }
    let pace = seconds / (distance / AnalysisConstants.metersPerKilometer)
    let share = min(max(1 - (pace / targetPace - 1) / AnalysisConstants.raceSlowMargin, 0), 1)
    return ScoreItem(
        part: .execution,
        points: share * AnalysisConstants.executionWeight,
        maximum: AnalysisConstants.executionWeight,
        reason: share < 1 ? .slowerThanTarget : nil
    )
}

private func raceIntentItem(_ race: RaceScoreInput, splits: [WorkoutBlock]) -> ScoreItem {
    let targetPace = race.targetPace
    guard targetPace != nil || !race.referencePaces.isEmpty else { return absent(.intent, .noRaceTarget) }
    let checks = splits.enumerated().compactMap { index, split -> Bool? in
        guard split.distance >= AnalysisConstants.raceFullKilometer, split.seconds > 0,
              let reference = race.referencePaces[index] ?? targetPace else { return nil }
        let pace = split.seconds / (split.distance / AnalysisConstants.metersPerKilometer)
        return abs(pace - reference) <= AnalysisConstants.racePaceTolerance
    }
    guard !checks.isEmpty else { return absent(.intent, .noSplits) }
    let share = Double(checks.filter { $0 }.count) / Double(checks.count)
    return ScoreItem(
        part: .intent,
        points: share * AnalysisConstants.intentWeight,
        maximum: AnalysisConstants.intentWeight,
        reason: share < 1 ? .offStrategy : nil
    )
}
