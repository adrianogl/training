import Foundation
import TrainingCore

public enum TrainingStatus {
    public static func phrase(client: GarminAccountClient, day: Day) async throws -> String? {
        let data = try await client.get("\(TrainingStatusConstants.path)/\(day.iso)")
        let response = try JSONDecoder().decode(TrainingStatusResponse.self, from: data)
        let devices = response.mostRecentTrainingStatus?.latestTrainingStatusData.map { Array($0.values) } ?? []
        let device = devices.first { $0.primaryTrainingDevice == true } ?? devices.first
        return device?.trainingStatusFeedbackPhrase
    }
}
