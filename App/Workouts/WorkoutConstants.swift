import Foundation

enum WorkoutConstants {
    static let listWidth: Double = 360
    static let splitMinWidth: CGFloat = 1000
    static let weekRangeFormat = "%@–%@"
    static let weekDayFormat = "d"
    static let weekMonthFormat = "d MMM"
    static let weekSummaryFormat = "%@ km · %d corridas"
    static let weekSummarySingular = "%@ km · 1 corrida"
    static let weekPlannedFormat = "%@ de %@ km · %d corridas"
    static let weekPlannedSingular = "%@ de %@ km · 1 corrida"
    static let weekStrengthFormat = "%@ · %d de força"
    static let weekStrengthOnlyFormat = "%d de força"
    static let weekBarHeight: Double = 4
    static let emptyFilter = "Nenhum treino desse tipo"
    static let emptyFilterText = "Troque o filtro para ver os outros treinos."
    static let filterTitles: [WorkoutKindFilter: String] = [
        .all: "Todos",
        .run: "Corrida",
        .strength: "Força",
    ]
    static let emptyList = "Nenhum treino ainda"
    static let emptyListText = "Os treinos aparecem aqui depois da sincronização com o Garmin."
    static let listTitle = "Treinos"
    static let selectWorkout = "Escolha um treino na lista."
    static let plannedTitle = "Planejados"
    static let plannedHeaderFormat = "%@ · %d"
    static let fromPlan = "do plano"
    static let structured = "estruturado"
    static let metricsSeparator = " · "
    static let upcomingMarker = "↑ próximos treinos"
    static let listTopAnchor = "workoutListTopAnchor"
    static let plannedToday = "hoje"
    static let plannedTag = "planejado"
    static let plannedBadge = "Planejado"
    static let strengthTag = "força"
    static let programSource = " · professor no MFIT"
    static let strengthSetsFormat = "%d séries"
    static let newBadge = "novo"
    static let plannedKind = "Treino planejado"
    static let plannedDetailSubtitle = "Planejado no Garmin Connect"
    static let plannedDays = 6
    static let plannedMaxDays = 180
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
    static let scoreKeyWeatherScale = 1000.0
    static let analysisStoreVersion = 1
    static let scoreKeyFieldSeparator = ":"
    static let scoreKeyFloorSeparator = "/"
}
