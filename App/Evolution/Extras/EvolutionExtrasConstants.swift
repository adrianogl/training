import Foundation

enum EvolutionExtrasConstants {
    static let zoneWeeks = 8
    static let zoneCount = 5
    static let easyZones = 2
    static let zonesTitle = "Tempo por zona por semana"
    static let zonesFootFormat = "%d%% do tempo em Z1–Z2 nas últimas %d semanas."
    static let recordsTitle = "Recordes pessoais"
    static let recordsEmpty = "Sem corridas suficientes para recordes."
    static let newRecord = "novo"
    static let recentDays = 7
    static let secondsPerDay = 86_400.0
    static let records: [(label: String, meters: Double)] = [("1 km", 1_000), ("5 km", 5_000), ("10 km", 10_000), ("21,1 km", 21_097.5), ("42,2 km", 42_195)]
    static let splitSource = "melhor trecho"
    static let runSource = "corrida"
    static let recordDateFormat = "dd/MM/yy"
    static let recordMissing = "ainda sem"
    static let recordLabelWidth: CGFloat = 62
    static let zoneLabels = ["Z1", "Z2", "Z3", "Z4", "Z5"]
}
