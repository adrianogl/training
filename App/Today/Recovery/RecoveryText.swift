import Foundation

enum RecoveryText {
    private typealias C = RecoveryConstants

    static func dayHour(_ date: Date, calendar: Calendar = .current) -> String {
        let weekday = date.formatted(.dateTime.weekday(.abbreviated).locale(WorkoutConstants.locale))
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let time = minute == 0 ? String(format: C.hourFormat, hour) : String(format: C.hourMinuteFormat, hour, minute)
        return String(format: C.readyAtFormat, weekday, time)
    }

    static func name(_ next: RecoveryNext) -> String {
        guard let km = next.kilometers, !next.title.lowercased().contains("km") else { return next.title }
        return String(format: C.nextKilometersFormat, next.title, TodayText.decimal(km, fractionDigits: km.rounded() == km ? 0 : 1))
    }
}
