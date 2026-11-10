import Foundation
import Metrics
import TrainingCore
import WorkoutAnalysis

enum RacesText {
    typealias C = RacesConstants

    static func signedClock(_ value: Double?, minus reference: Double?) -> String? {
        guard let value, let reference else { return nil }
        let delta = value - reference
        let magnitude = WorkoutFormat.clock(abs(delta))
        if Int(abs(delta).rounded()) == 0 { return magnitude }
        return (delta > 0 ? "+" : TodayConstants.minusSign) + magnitude
    }

    static func paceText(_ secondsPerKm: Double) -> String {
        "\(WorkoutFormat.clock(secondsPerKm)) \(WorkoutConstants.paceUnit)"
    }

    static func goalPaceText(goalSeconds: Double, distance: Double) -> String {
        paceText(goalSeconds / (distance / C.metersPerKm))
    }

    static func distanceText(_ meters: Double) -> String {
        if let option = C.distanceMeters.first(where: { abs($0.value - meters) < C.distanceTolerance })?.key,
           let title = C.distanceTitles[option] {
            return title
        }
        return WorkoutListModel.distanceText(meters)
    }

    static func dateText(_ day: Day) -> String {
        "\(day.day) de \(TodayConstants.months[day.month - 1]) de \(day.year)"
    }

    static func header(priority: String, day: Day, today: Day) -> String {
        let days = today.days(until: day)
        let countdown = days == 0 ? C.today : "\(days) \(days == 1 ? "dia" : "dias")"
        return "prova \(priority) · \(day.day) de \(TodayConstants.months[day.month - 1]) · \(countdown)"
    }

    static func assessmentSentence(goalSeconds: Double, referenceSeconds: Double, reference: AssessmentReference) -> String? {
        guard let level = assessGoal(goalSeconds: goalSeconds, predictionSeconds: referenceSeconds),
              let word = C.assessmentWords[level]
        else { return nil }
        let gap = (referenceSeconds - goalSeconds) / referenceSeconds * 100
        let side = gap >= 0 ? C.below : C.above
        let target = reference == .raceDayProjection ? C.referenceRaceDay : C.referenceToday
        return String(format: C.assessmentFormat, word, TodayText.decimal(abs(gap), fractionDigits: 1), side, target)
    }

    static func blockReading(block: [BlockWeek], today: Day, longestRun: Double?, longRunTarget: Double) -> String {
        let currentWeek = today.weekStart
        let recent = (1...C.recentWeeks).map { offset in
            block.first { $0.start == currentWeek.adding(days: -C.daysPerWeek * offset) }?.km
        }
        let known = recent.compactMap { $0 }
        let average = known.isEmpty ? 0 : known.reduce(0, +) / Double(known.count)
        guard let first = block.first, first.start <= currentWeek else {
            let weeks = block.first.map { currentWeek.days(until: $0.start) / C.daysPerWeek } ?? 0
            return String(format: C.blockReadingBeforeFormat, weeks, km(average))
        }
        let week = first.start.days(until: currentWeek) / C.daysPerWeek + 1
        let biggest = block.filter { !$0.projected }.map(\.km).max() ?? 0
        return String(
            format: C.blockReadingFormat,
            min(week, block.count), block.count, km(average), km(biggest),
            km((longestRun ?? 0) / C.metersPerKm), km(longRunTarget / C.metersPerKm)
        )
    }

    static func lesson(resultSeconds: Double?, goalSeconds: Double?, eveSeconds: Double?, splits: [RaceSplit]) -> String {
        guard let resultSeconds else { return C.lessonNoResult }
        var text: String
        if let goal = signedClock(resultSeconds, minus: goalSeconds) {
            text = String(format: C.lessonGoalFormat, WorkoutFormat.clock(resultSeconds), goal)
        } else {
            text = String(format: C.lessonNoGoalFormat, WorkoutFormat.clock(resultSeconds))
        }
        if let eve = signedClock(resultSeconds, minus: eveSeconds) {
            text += String(format: C.lessonEveFormat, eve)
        } else {
            text += C.lessonNoEve
        }
        text += "."
        let full = splits.filter { $0.distance >= C.metersPerKm * 0.99 }
        guard full.count >= 2 else { return text }
        let half = full.count / 2
        let firstPace = full.prefix(half).map(\.pace).reduce(0, +) / Double(half)
        let secondPace = full.suffix(full.count - half).map(\.pace).reduce(0, +) / Double(full.count - half)
        let verdict = abs(secondPace - firstPace) <= C.evenSplitTolerance
            ? C.evenSplit
            : (secondPace < firstPace ? C.negativeSplit : C.positiveSplit)
        text += String(format: C.lessonSplitsFormat, WorkoutFormat.clock(firstPace), WorkoutFormat.clock(secondPace), verdict)
        return text
    }

    static func km(_ value: Double) -> String {
        TodayText.decimal(value, fractionDigits: value.rounded() == value || value >= 100 ? 0 : 1)
    }

    static func grade(_ value: Double) -> String {
        TodayText.signed(value * 100, fractionDigits: 1) + "%"
    }
}
