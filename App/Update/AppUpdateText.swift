enum AppUpdateText {
    static func title(_ update: AppUpdate) -> String {
        "Versão \(update.latest) disponível"
    }

    static func body(_ update: AppUpdate) -> String {
        "Este aparelho está na \(update.installed). Instale pelo Mac para receber as novidades."
    }

    static func noticeText(_ update: AppUpdate) -> String {
        update.notes.isEmpty
            ? body(update)
            : "Este aparelho está na \(update.installed). Instale pelo Mac para receber as novidades:"
    }

    static let openSettings = "Ver em Ajustes"
    static let dismiss = "Agora não"
}
