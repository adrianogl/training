import Foundation
import Insights
import TrainingCore
import WorkoutAnalysis

extension Day {
    var chartDate: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }
}

enum TodayText {
    typealias C = TodayConstants

    static func goalClock(_ seconds: Double) -> String {
        let text = WorkoutFormat.clock(seconds)
        return text.hasSuffix(":00") && text.split(separator: ":").count == 3 ? String(text.dropLast(3)) : text
    }

    static func decimal(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)).locale(WorkoutConstants.locale))
    }

    static func signed(_ value: Double, fractionDigits: Int = 0) -> String {
        let magnitude = decimal(abs(value), fractionDigits: fractionDigits)
        if value > 0 { return "+" + magnitude }
        if value < 0, Double(magnitude.replacingOccurrences(of: ",", with: ".")) != 0 { return C.minusSign + magnitude }
        return magnitude
    }

    static func monthPart(_ day: Day) -> String {
        if day.day <= C.earlyMonthLimit { return "início" }
        if day.day <= C.midMonthLimit { return "meados" }
        return "fim"
    }

    static func goalSentence(crossing: GoalCrossing, goalSeconds: Double?, hasPrediction: Bool, raceDay: Day?) -> String? {
        guard let goalSeconds, hasPrediction else { return nil }
        switch crossing {
        case .noGoal:
            return nil
        case .alreadyBeaten:
            return C.goalBeaten
        case .unreachable:
            return C.goalUnreachable
        case .on(let day):
            var suffix = ""
            if let raceDay, day > raceDay {
                let weeks = Int((Double(raceDay.days(until: day)) / C.daysPerWeek).rounded())
                if weeks >= 1 {
                    suffix = String(format: C.goalAfterRace, weeks, weeks == 1 ? "semana" : "semanas")
                }
            }
            return String(format: C.goalOn, goalClock(goalSeconds), monthPart(day), C.months[day.month - 1], suffix)
        }
    }

    static func countdown(days: Int?, priority: String?) -> String? {
        guard let days else { return nil }
        if days == 0 { return "prova \(priority ?? "") hoje".replacingOccurrences(of: "  ", with: " ") }
        let unit = days == 1 ? "dia" : "dias"
        return "prova \(priority ?? "") em \(days) \(unit)".replacingOccurrences(of: "  ", with: " ")
    }

    static func readinessSummary(score: Int, normal: Double?) -> String {
        guard let normal else { return C.detailNoNormal }
        let rounded = Int(normal.rounded())
        let delta = score - rounded
        if delta == 0 { return "No seu normal (\(rounded))" }
        return delta > 0
            ? "+\(delta) sobre o seu normal (\(rounded))"
            : "\(-delta) abaixo do seu normal (\(rounded))"
    }

    static func sleepDuration(_ seconds: Int) -> String {
        "\(seconds / 3_600)h\(String(format: "%02d", (seconds % 3_600) / 60))"
    }
}
