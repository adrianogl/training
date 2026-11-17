import Insights
enum WatchFaceConstants {
    static let phaseNames: [TrainerPhase: String] = [
        .general: "Base geral", .base: "Base", .build: "Construção", .specific: "Específica", .taper: "Polimento",
    ]
    static let lightWeek = "Semana leve"
    static let nextWeekFormat = "%@ · %d km"
    static let trainingStatusKeys: Set<String> = [
        "PRODUCTIVE", "MAINTAINING", "PEAKING", "RECOVERY", "UNPRODUCTIVE", "DETRAINING", "OVERREACHING", "STRAINED",
    ]
    static let vo2WindowDays = 90
    static let vo2Precision = 10.0
    static let weekKmPrecision = 10.0
    static let shapeWeightScale = 100.0
    static let shapeMaxSteps = 24
    static let daysPerWeek = 7
    static let metersPerKm = 1_000.0
    static let goalNameFormat = "META %@K"
    static let goalNameMaxLength = 14
    static let goalWholeTolerance = 0.05
    static let goalWholeFrom = 20.0
}
