struct TrainingStatusResponse: Decodable {
    let mostRecentTrainingStatus: TrainingStatusSummary?
}

struct TrainingStatusSummary: Decodable {
    let latestTrainingStatusData: [String: TrainingStatusDevice]?
}

struct TrainingStatusDevice: Decodable {
    let trainingStatusFeedbackPhrase: String?
    let primaryTrainingDevice: Bool?
}
