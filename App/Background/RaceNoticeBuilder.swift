import Foundation
import GarminAPI
import TrainingCore
import WorkoutAnalysis

struct RaceNotice: Equatable {
    let id: String
    let title: String
    let text: String
    let date: Date
}

enum RaceNoticeBuilder {
    private typealias C = RaceNoticeConstants

    static func notices(id: UUID, name: String, day: Day, startTime: String?, distance: Double, goalSeconds: Double?, plan: PaceProPlan?, calendar: Calendar = .current) -> [RaceNotice] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = C.timeFormat
        let startText = startTime ?? C.defaultStart
        guard let clock = formatter.date(from: startText) else { return [] }
        let parts = calendar.dateComponents([.hour, .minute], from: clock)
        guard let start = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: parts.hour, minute: parts.minute)) else { return [] }
        let wake = start.addingTimeInterval(-C.wakeBeforeStart)
        let bed = wake.addingTimeInterval(-C.sleepHours)
        let eat = wake.addingTimeInterval(C.eatAfterWake)
        let goal = goalSeconds.map { "Meta \(WorkoutFormat.clock($0)), \(WorkoutFormat.clock($0 * 1_000 / distance))/km. " } ?? ""
        let gel = distance >= C.gelMinimumMeters ? " Separe também o gel." : ""
        let eve = RaceNotice(
            id: C.eveIdPrefix + id.uuidString,
            title: "\(name) amanhã, largada \(startText)",
            text: "\(goal)Para dormir 8 h e acordar às \(formatter.string(from: wake)), deite até \(formatter.string(from: bed)). Separe número, chip e tênis hoje.\(gel)",
            date: bed.addingTimeInterval(-C.noticeBeforeBed)
        )
        let morning = RaceNotice(
            id: C.morningIdPrefix + id.uuidString,
            title: "Hoje é a \(name)",
            text: "Largada \(startText). \(paceText(plan: plan, goalSeconds: goalSeconds, distance: distance))Coma até \(formatter.string(from: eat)) e abra o app para ver a prontidão.",
            date: wake
        )
        return [eve, morning]
    }

    static func paceText(plan: PaceProPlan?, goalSeconds: Double?, distance: Double) -> String {
        if let seconds = plan?.kilometerSeconds, let first = seconds.first {
            let rest = Array(seconds.dropFirst())
            guard !rest.isEmpty else { return "Pace Pro: \(WorkoutFormat.clock(first))/km. " }
            let typical = rest.sorted()[rest.count / 2]
            return "Pace Pro: 1º km em \(WorkoutFormat.clock(first)), depois \(WorkoutFormat.clock(typical))/km até o fim. "
        }
        guard let goalSeconds, distance > 0 else { return "" }
        return "Ritmo da meta: \(WorkoutFormat.clock(goalSeconds * 1_000 / distance))/km. "
    }
}
