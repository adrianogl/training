import Foundation

enum TrainerZoneGuideConstants {
    static let realPaceDays = 42
    static let title = "Zonas e ritmos"
    static let zoneHeader = "Zona"
    static let heartRateHeader = "FC"
    static let paceHeader = "Pace"
    static let usesHeader = "Usado em"
    static let realTitle = "Seu pace real na zona · 42 dias"
    static let trot = "trote"
    static let noThreshold = "Sem limiar do relógio ainda: as faixas de FC aparecem depois do primeiro treino com FC."
    static let slowerThanPlan = "Seu pace real em Z%d está mais lento que o prescrito: a FC sobe antes do pace."
    static let fasterThanPlan = "Seu pace real em Z%d está mais rápido que o prescrito: dá para correr na faixa com folga."
    static let realTolerance = 8.0
    static let uses: [Int: String] = [
        1: "descanso, trote",
        2: "rodagem, longão, aquecimento",
        3: "pace-alvo",
        4: "tempo, limiar",
        5: "VO2, tiros de 100 m",
    ]
}
