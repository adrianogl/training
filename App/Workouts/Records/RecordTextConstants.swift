import Foundation

enum RecordTextConstants {
    static let labels: [Double: String] = [1_000: "1 km", 3_000: "3 km", 5_000: "5 km", 10_000: "10 km", 21_097.5: "Meia maratona", 42_195: "Maratona"]
    static let inPhrases: [Double: String] = [
        1_000: "no 1 km", 3_000: "nos 3 km", 5_000: "nos 5 km", 10_000: "nos 10 km", 21_097.5: "na meia maratona", 42_195: "na maratona",
    ]
    static let pillLabels: [Double: String] = [21_097.5: "meia", 42_195: "maratona"]
    static let inPhraseFallbackFormat = "nos %@"
    static let firstTitles: [Double: String] = [
        1_000: "Primeiro 1 km", 3_000: "Primeiros 3 km", 5_000: "Primeiros 5 km", 10_000: "Primeiros 10 km",
        21_097.5: "Primeira meia maratona", 42_195: "Primeira maratona",
    ]
    static let recordTitleFormat = "Recorde %@"
    static let recordOne = "1 recorde"
    static let recordsFormat = "%d recordes"
    static let goalOne = "1 meta"
    static let goalsFormat = "%d metas"
    static let countsJoin = " e "
    static let titleJoin = " · "
    static let wholeBodyFormat = "%@, %@ abaixo do anterior (%@, %@)."
    static let segmentBodyFormat = "Melhor %@ em %@, %@ abaixo do anterior (%@, %@)."
    static let firstBodyFormat = "%@ %@, o primeiro tempo na distância."
    static let nearBodyFormat = "%@ %@, a %@ do recorde."
    static let listItemFormat = "%@ em %@ (−%@)"
    static let listFirstFormat = "%@ em %@ (primeiro tempo)"
    static let recordsListFormat = "Recordes: %@."
    static let recordListSingleFormat = "Recorde: %@."
    static let goalsListFormat = "Metas: %@."
    static let goalListSingleFormat = "Meta: %@."
    static let secondsFormat = "%d s"
    static let minuteSeconds = 60.0
    static let dateFormat = "dd/MM"
    static let listSeparator = ", "
    static let listLast = " e "
    static let pillSingleFormat = "RP %@"
    static let pillCountFormat = "%d RP"
    static let goalPillSingle = "Meta"
    static let goalPillFormat = "%d metas"
    static let recordSymbol = "★ "
    static let goalSymbol = "✓ "
}
