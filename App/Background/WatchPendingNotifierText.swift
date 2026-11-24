enum WatchPendingNotifierText {
    static let sendAction = "Enviar ao Garmin"
    static let tapToSend = "Toque para enviar."

    static func title(_ items: [TrainerSendItem]) -> String {
        guard items.count == 1, let item = items.first else { return "\(items.count) treinos de amanhã não estão no Garmin" }
        return "\(item.title) de amanhã não está no Garmin"
    }

    static func body(_ items: [TrainerSendItem], records: [String: TrainerSentRecord]) -> String {
        guard items.count == 1, let item = items.first, TrainerSendBuilder.status(item, records: records) == .changed else { return tapToSend }
        return "O plano mudou para \(item.title) e o relógio ainda tem a versão anterior."
    }
}
