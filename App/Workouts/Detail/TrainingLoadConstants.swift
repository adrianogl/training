import Foundation

enum TrainingLoadConstants {
    static let plain = "carga"
    static let windowDays = 90
    static let minimumRuns = 8
    static let levels: [(upTo: Double, text: String)] = [
        (0.33, "carga baixa"), (0.67, "carga média"), (0.9, "carga alta"), (1.01, "carga top 10%"),
    ]
}
