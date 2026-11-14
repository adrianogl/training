enum RaceTaperConstants {
    static let windowDays = 14
    static let chartHeight = 90.0
    static let baseWeeks = 4
    static let firstWeekShare = 0.68
    static let raceWeekShare = 0.45
    static let longShare = 0.65
    static let daysPerWeek = 7
    static let metersPerKm = 1_000.0
    static let historyWindowDays = 14
    static let historyBaseDays = 28
    static let title = "Polimento"
    static let weekFormat = "semana %d de %d"
    static let adviceFormat = "Reduza 30 a 40%% do volume, mantendo um treino curto no pace de prova. Evite tiros longos e longão acima de %@ km."
    static let bestFormat = "Na %@, você reduziu %d%% nas duas semanas antes e correu %@ da meta."
    static let bestKeptFormat = "Na %@, você manteve o volume nas duas semanas antes e correu %@ da meta."
    static let keptThreshold = 0.05
    static let baseFormat = "Base: %@ km/semana nas 4 semanas antes do polimento."
    static let race = "prova"
    static let targetLabel = "alvo"
}
