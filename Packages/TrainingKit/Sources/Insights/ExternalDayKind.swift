import Foundation
import TrainingCore

public enum ExternalDayKind {
    static let thresholdWords = ["limiar", "ritmo", "tempo", "threshold"]
    static let vo2Words = ["vo2", "intervalado", "tiro", "fartlek"]
    static let longWords = ["longo", "longao"]
    static let raceWords = ["prova"]
    static let longMeters = 18_000.0

    public static func kind(_ workout: TrainerExternalWorkout) -> TrainerDayKind {
        let name = workout.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
        if raceWords.contains(where: name.contains), !thresholdWords.contains(where: name.contains) { return .race }
        if vo2Words.contains(where: name.contains) { return .vo2max }
        if longWords.contains(where: name.contains) || workout.totalMeters >= longMeters { return .long }
        if thresholdWords.contains(where: name.contains) { return .threshold }
        return .easy
    }

    public static func structure(_ workouts: [TrainerExternalWorkout], week: Day) -> [Int: TrainerDayKind] {
        Dictionary(
            workouts.filter { $0.day.weekStart == week }.map { ($0.day.weekStart.days(until: $0.day) + 1, kind($0)) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
