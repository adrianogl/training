import FITReader
import Foundation
import Storage

private typealias C = WorkoutKindConstants

public func classifyRun(_ record: ActivityRecord, longGoalKm: Double?, raceGoalKms: [Double]) -> RunKind {
    let structure = record.structureData.flatMap { try? JSONDecoder().decode(WorkoutStructure.self, from: $0) }
    let steps = structure?.prescription?.steps ?? []
    if steps.contains(where: { isRepeat($0.duration) }) { return .intervals }
    let names = [record.workoutName, structure?.prescription?.name, record.name].compactMap { $0 }.joined(separator: " ")
    let text = normalized(names)
    if mentions(text, C.raceWords) { return .race }
    if mentions(text, C.intervalWords) { return .intervals }
    if mentions(text, C.longWords) { return .long }
    if mentions(text, C.tempoWords) { return .tempo }
    if mentions(text, C.easyWords) { return .easy }
    if steps.contains(where: { $0.intensity == .active && isHardZone($0.target) }) { return .tempo }
    let meters = record.distance ?? 0
    if raceGoalKms.contains(where: { meters >= $0 * 1_000 * C.raceLow && meters <= $0 * 1_000 * C.raceHigh }) { return .race }
    if hasRepeatedActiveLaps(structure?.laps ?? []) { return .intervals }
    if isLongRun(name: names, distanceMeters: meters, goalKm: longGoalKm) { return .long }
    return .easy
}

public func isLongRun(name: String, distanceMeters: Double, goalKm: Double?) -> Bool {
    let text = normalized(name)
    if mentions(text, C.longWords) { return true }
    if mentions(text, C.intervalWords + C.easyWords) { return false }
    let minimum = max((goalKm ?? 0) * 1_000 * C.longShare, C.longMinimumMeters)
    return distanceMeters >= minimum
}

private func normalized(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
}

private func mentions(_ text: String, _ words: [String]) -> Bool {
    words.contains { text.contains($0) }
}

private func isRepeat(_ duration: StepDuration) -> Bool {
    if case .repeatSteps = duration { return true }
    return false
}

private func isHardZone(_ target: StepTarget) -> Bool {
    if case .heartRateZone(let zone) = target { return zone >= C.tempoZone }
    return false
}

private func hasRepeatedActiveLaps(_ laps: [LapSummary]) -> Bool {
    laps.filter { $0.intensity == .active }.count >= C.intervalActiveLaps
        && laps.filter { $0.intensity == .recovery }.count >= C.intervalRecoveryLaps
}
