import Foundation
import TrainingCore

enum RaceTargetBuilder {
    static func prediction(today: Double?, raceDay: Double?) -> Double? {
        raceDay ?? today
    }

    static func target(_ info: RaceInfo, todayPrediction: Double?, raceDayPrediction: Double?, today: Day) -> RaceTargetData {
        let prediction = prediction(today: todayPrediction, raceDay: raceDayPrediction)
        return RaceTargetData(
            id: info.id,
            name: info.name,
            dateText: RacesText.shortDate(info.day),
            distanceText: RacesText.distanceText(info.distance),
            days: max(today.days(until: info.day), 0),
            predictionSeconds: prediction,
            goalSeconds: info.goalSeconds,
            gapText: RacesText.goalGapText(prediction: prediction, goal: info.goalSeconds)
        )
    }
}
