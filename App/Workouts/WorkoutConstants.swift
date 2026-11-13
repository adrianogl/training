import Foundation

enum WorkoutConstants {
    static let listWidth: Double = 360
    static let weekRangeFormat = "%@–%@"
    static let weekDayFormat = "d"
    static let weekMonthFormat = "d MMM"
    static let weekSummaryFormat = "%@ km · %d corridas"
    static let weekSummarySingular = "%@ km · 1 corrida"
    static let emptyList = "Nenhuma corrida ainda."
    static let listTitle = "Treinos"
    static let selectWorkout = "Escolha uma corrida na lista."
    static let plannedTitle = "Planejados"
    static let plannedToday = "hoje"
    static let plannedTag = "planejado"
    static let plannedDetailSubtitle = "Planejado no Garmin Connect"
    static let plannedDays = 6
    static let plannedStructure = "Estrutura"
    static let plannedSteps = "Passos"
    static let plannedLastTime = "Da última vez que você fez"
    static let plannedLastTimeFormat = "%@ · %@ km · %@"
    static let locale = Locale(identifier: "pt_BR")
    static let metersPerKilometer = 1_000.0
    static let paceUnit = "/km"
    static let distanceUnit = "km"
    static let scoreKeySeparator = "|"
    static let scoreKeyIdSeparator = ","
    static let scoreKeyMissing = "-"
    static let scoreKeyFieldSeparator = ":"
    static let scoreKeyFloorSeparator = "/"
}
