enum WorkoutGoalConstants {
    static let cardTitle = "Meta"
    static let timeMatchLow = 0.99
    static let timeMatchHigh = 1.05
    static let paceGoalDistances: Set<Double> = [5, 10]
    static let paceTolerance = 1.0
    static let met = "cumprida"
    static let almost = "quase"
    static let notYet = "ainda não"
    static let pausesOne = "1 pausa"
    static let pausesFormat = "%d pausas"
    static let noFit = "Sem o arquivo FIT deste treino, não dá para ver as pausas."
    static let pauseLineFormat = "Pausa de %d s no km %@."
    static let longestFormat = "Maior trecho sem parar: %@ km."
    static let longestComparedFormat = "Maior trecho sem parar: %@ km (no longão anterior: %@ km)."
    static let fullDistanceFormat = "Correu %@ km sem nenhuma pausa."
    static let shortFormat = "Faltaram %@ km para a distância da meta."
    static let paceOkFormat = "Pace médio %@/km, dentro da meta de %@/km."
    static let paceSlowFormat = "Pace médio %@/km, %d s/km acima da meta de %@/km."
    static let blocksFasterFormat = "Blocos fortes a %@/km, %d s/km mais rápido que o pace da meta (%@/km)."
    static let blocksEqualFormat = "Blocos fortes a %@/km, no pace da meta."
    static let blocksSlowerFormat = "Blocos fortes a %@/km, %d s/km mais lento que o pace da meta (%@/km)."
    static let blocksNote = "É o ritmo que a meta pede pela distância inteira."
    static let raceTimeFormat = "%@ em %@: %@."
    static let raceBeaten = "meta batida"
    static let raceMissFormat = "%@ acima da meta"
    static let paceStatus = "pace da meta"
}
