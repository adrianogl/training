import Foundation

enum NoticeInboxText {
    private typealias C = NoticeInboxViewConstants

    static let title = "Avisos"
    static let markAllRead = "Marcar como lidos"
    static let close = "Fechar"
    static let fresh = "Novos"
    static let earlier = "Anteriores"
    static let empty = "Nenhum aviso nos últimos 30 dias."
    static let planSource = "Treinador"
    static let planLink = "Ver o que mudou"
    static let unread = "não lido"
    static let fallbackTitle = "trAIning"
    static let yesterday = "ontem"
    static let garmin = "Garmin"
    static let garminCurrent = "No Garmin"
    static let garminSend = "Enviar"
    static let titlesByIdPrefix = [
        (BackgroundConstants.notificationIdPrefix, "Prontidão de hoje"),
        (WeeklyReportConstants.notificationId, "Resumo da semana"),
    ]

    static func bellLabel(unread count: Int) -> String {
        switch count {
        case 0: title
        case 1: "\(title), 1 não lido"
        default: "\(title), \(count) não lidos"
        }
    }

    static func garminPending(_ count: Int) -> String {
        count == 1 ? "1 treino esperando envio" : "\(count) treinos esperando envio"
    }

    static func badge(_ count: Int) -> String {
        count > C.badgeLimit ? "\(C.badgeLimit)+" : String(count)
    }

    static func title(_ entry: NoticeEntry) -> String {
        if let title = entry.title, !title.isEmpty { return title }
        return titlesByIdPrefix.first { entry.id.hasPrefix($0.0) }?.1 ?? fallbackTitle
    }

    static func fullDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute().locale(C.locale))
    }

    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(.dateTime.hour().minute().locale(C.locale))
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 1 { return yesterday }
        if days <= C.recentDays {
            return date.formatted(.dateTime.weekday(.abbreviated).locale(C.locale))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(C.locale))
    }

    static func rowLabel(_ entry: NoticeEntry) -> String {
        [title(entry), entry.text, entry.isRead ? when(entry.deliveredAt) : unread].joined(separator: ", ")
    }
}
