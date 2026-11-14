enum RecoveryConstants {
    static let baseHours: [(effect: Double, hours: Double)] = [(0, 12), (2, 24), (3, 30), (3.5, 42), (4, 54), (4.5, 66)]
    static let anaerobicHeavy = 3.0
    static let anaerobicExtraHours = 12.0
    static let lowReadiness = 50
    static let goodReadiness = 70
    static let lowReadinessExtraHours = 12.0
    static let goodReadinessSavedHours = 6.0
    static let defaultHour = 7
    static let recentRunsForHour = 10
    static let lookAheadDays = 7
    static let title = "Recuperação estimada"
    static let readyFormat = "pronto em %d h · %@"
    static let whenFormat = "%@ %dh"
    static let readyNow = "recuperado"
    static let afterFormat = "%d h depois"
    static let enough = "ok"
    static let short = "curto"
    static let sinceFormat = "desde %@"
    static let shortNoteFormat = "%@ vem %d h depois; o ideal seriam %d h. Faça mais leve se as pernas estiverem pesadas."
    static let enoughNoteFormat = "%@ vem %d h depois: dá tempo de recuperar."
}
