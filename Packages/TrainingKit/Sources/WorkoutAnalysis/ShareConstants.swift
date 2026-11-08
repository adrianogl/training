enum ShareConstants {
    static let fieldSeparator = ","
    static let titleSeparator = " · "
    static let minimumRoutePoints = 2
    static let minimumBarHeight = 0.2
    static let distanceUnit = "km"
    static let elevationUnit = "m"

    static let fullLabels: [ShareField: String] = [
        .distance: "distância",
        .time: "tempo",
        .avgPace: "pace médio",
        .avgHeartRate: "FC média",
        .activePace: "pace dos tiros",
        .elevation: "desnível",
    ]

    static let shortLabels: [ShareField: String] = [
        .distance: "distância",
        .time: "tempo",
        .avgPace: "pace",
        .avgHeartRate: "FC",
        .activePace: "tiros",
        .elevation: "desnível",
    ]
}
