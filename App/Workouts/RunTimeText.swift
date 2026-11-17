import Foundation
import TrainingCore
import WorkoutAnalysis

enum RunTimeText {
    private typealias C = RunTimeConstants

    static func range(_ range: RunTimeRange) -> String {
        let low = Int((range.fastest / 60).rounded(.down))
        let high = max(Int((range.slowest / 60).rounded(.up)), low)
        let text: String
        if low == high {
            text = minutes(low)
        } else if high < 60 {
            text = "\(low)\(C.separator)\(high)\(C.minutesSuffix)"
        } else {
            text = "\(minutes(low))\(C.separator)\(minutes(high))"
        }
        return range.approximate ? C.approximatePrefix + text : text
    }

    static func step(_ range: RunTimeRange, repeated: Bool) -> String {
        let text = range.fastest.rounded() == range.slowest.rounded()
            ? WorkoutFormat.clock(range.fastest)
            : "\(WorkoutFormat.clock(range.fastest))\(C.separator)\(WorkoutFormat.clock(range.slowest))"
        return repeated ? text + C.eachSuffix : text
    }

    private static func minutes(_ total: Int) -> String {
        total >= 60 ? String(format: C.hoursFormat, total / 60, total % 60) : "\(total)\(C.minutesSuffix)"
    }
}
