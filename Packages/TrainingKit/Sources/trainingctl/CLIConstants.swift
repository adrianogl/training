import Foundation

enum CLIConstants {
    static let keyRelativePath = ".config/garmin/connect-personal-api-key"
    static let runTypeKeyMarker = "running"
    static let intervalAnaerobicEffect = 2.0
    static let predictionDistances: [(meters: Double, label: String)] = [
        (5_000, "5 km"),
        (10_000, "10 km"),
        (21_097.5, "21,1 km"),
        (42_195, "42,2 km"),
    ]
    static let split5kMeters = 5_000.0
    static let split1kMeters = 1_000.0
    static let missing = "—"
    static let usageExitCode: Int32 = 64
    static let failureExitCode: Int32 = 1
    static let usage = """
        uso: trainingctl <sync|report> --store <caminho>
          sync    baixa os dados do Garmin para o store SQLite
          report  imprime as métricas calculadas a partir do store
        """
}
