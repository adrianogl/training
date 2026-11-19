import Foundation

enum InstallExpiryText {
    static func title(daysLeft: Int) -> String {
        daysLeft <= 0 ? "O app para de abrir hoje" : "O app para de abrir amanhã"
    }

    static func notice(expiry: Date, calendar: Calendar) -> String {
        "A instalação vence em \(day(expiry, calendar: calendar)). Deixe o aparelho desbloqueado na mesma rede do Mac ou conecte por cabo para instalar de novo."
    }

    static func notification(expiry: Date, calendar: Calendar) -> String {
        "A instalação vence em \(day(expiry, calendar: calendar)). Deixe o aparelho perto do Mac para instalar de novo."
    }

    static func day(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        return String(format: "%02d/%02d", parts.day ?? 0, parts.month ?? 0)
    }
}
