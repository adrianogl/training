import Foundation

enum RaceNoticeConstants {
    static let eveIdPrefix = "race-eve-"
    static let morningIdPrefix = "race-morning-"
    static let link = "training://provas"
    static let defaultStart = "07:00"
    static let wakeBeforeStart: TimeInterval = 2 * 3600
    static let sleepHours: TimeInterval = 8 * 3600
    static let noticeBeforeBed: TimeInterval = 2 * 3600
    static let eatAfterWake: TimeInterval = 30 * 60
    static let gelMinimumMeters = 15_000.0
    static let lookAheadDays = 3
    static let timeFormat = "HH:mm"
}
