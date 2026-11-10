enum RaceConstants {
    static let effortWindowDays = 150.0
    static let kindWeight: [EffortKind: Double] = [.race: 1.0, .split5k: 0.7, .split1k: 0.3]

    static let aggressiveGap = 0.06
    static let challengingGap = 0.01

    static let shortRaceLimit = 10_000.0
    static let halfRaceLimit = 21_100.0
    static let halfLongRunShare = 0.9
    static let fullLongRunShare = 0.75

    static let warmupKms = 2
    static let warmupOffset = 5.0
    static let finishKms = 3
    static let finishOffset = -3.0
    static let climbLabelGrade = 0.02
    static let minettiGradeRange = -0.45...0.45

    static let warmupLabel = "aquece"
    static let finishLabel = "final"
    static let climbLabel = "subida"
    static let descentLabel = "descida"
    static let flatLabel = "plano"

    static let blockWeeks = 12
    static let projectionWeeks = 4

    static let taperDays = 14
    static let taperReduction = 0.4
    static let outlookHistoryDays = 120
    static let outlookProjectionDays = 30
    static let outlookLoadAverageDays = 28

    static let earthRadiusMeters = 6_371_000.0
}
