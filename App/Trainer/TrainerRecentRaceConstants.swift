struct TrainerRecentRaceDistance {
    let meters: Double
    let title: String
}

enum TrainerRecentRaceConstants {
    static let title = "Sem corridas no histórico"
    static let text = "Informe um tempo recente de prova ou de treino forte. Os ritmos do plano saem dele; depois o treinador ajusta pelas suas corridas."
    static let distanceLabel = "Distância"
    static let distances = [
        TrainerRecentRaceDistance(meters: 5000, title: "5 km"),
        TrainerRecentRaceDistance(meters: 10000, title: "10 km"),
        TrainerRecentRaceDistance(meters: 21097.5, title: "21 km"),
    ]
    static let defaultMinutes = 30
    static let minuteRange = 12...200
    static let timeFormat = "%d:%02d"
    static let secondsLabel = "Segundos"
    static let apply = "Usar este tempo"
    static let applied = "Atualizar ritmos"
}
