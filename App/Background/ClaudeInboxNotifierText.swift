enum ClaudeInboxNotifierText {
    static func title(count: Int) -> String {
        switch count {
        case 0: "Treinos de força do Claude"
        case 1: "1 treino de força do Claude"
        default: "\(count) treinos de força do Claude"
        }
    }

    static let body = "Prontos para revisar e aplicar no Treinador."
}
