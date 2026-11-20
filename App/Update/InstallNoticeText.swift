import Foundation

enum InstallNoticeText {
    static func title(_ event: InstallEvent) -> String {
        switch event {
        case .updated(let version, _): "trAIning \(version) instalado"
        case .renewed: "Instalação renovada"
        }
    }

    static func body(_ event: InstallEvent, calendar: Calendar) -> String {
        switch event {
        case .updated(_, let notes):
            notes.isEmpty ? "Toque para ver a versão em Ajustes." : "Novidades: " + notes.map(sentence).joined(separator: " ")
        case .renewed(let expiry):
            "O app vale até \(InstallExpiryText.day(expiry, calendar: calendar)) às \(hour(expiry, calendar: calendar)). Nada a fazer."
        }
    }

    static func cardTitle(_ card: InstalledCard) -> String {
        "Atualizado para a \(card.version)"
    }

    static let dismiss = "Ok"

    private static func sentence(_ note: String) -> String {
        note.hasSuffix(".") ? note : note + "."
    }

    private static func hour(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return parts.minute == 0 ? "\(parts.hour ?? 0)h" : String(format: "%dh%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}
