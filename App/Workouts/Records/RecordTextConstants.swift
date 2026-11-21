import Foundation

enum RecordTextConstants {
    static let labels: [Double: String] = [1_000: "1 km", 5_000: "5 km", 10_000: "10 km", 21_097.5: "21,1 km", 42_195: "42,2 km"]
    static let firstTitles: [Double: String] = [
        1_000: "Primeiro 1 km", 5_000: "Primeiros 5 km", 10_000: "Primeiros 10 km",
        21_097.5: "Primeira meia maratona", 42_195: "Primeira maratona",
    ]
    static let singleMeters = 1_000.0
    static let recordInSingular = "Recorde no %@"
    static let recordInPlural = "Recorde nos %@"
    static let recordOne = "1 recorde"
    static let recordsFormat = "%d recordes"
    static let goalOne = "1 meta"
    static let goalsFormat = "%d metas"
    static let countsJoin = " e "
    static let titleJoin = " · "
    static let wholeBodyFormat = "%@, %@ abaixo do anterior (%@, %@)."
    static let segmentBodyFormat = "Melhor %@ em %@, %@ abaixo do anterior (%@, %@)."
    static let firstBodyFormat = "%@ nos %@, o primeiro tempo na distância."
    static let nearBodyFormat = "%@ nos %@, a %@ do recorde."
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
