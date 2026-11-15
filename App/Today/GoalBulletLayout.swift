import Foundation
import WorkoutAnalysis

enum GoalBulletLayout {
    private typealias C = TodayConstants

    static func ticks(fastest: Double, slowest: Double) -> [GoalBulletTick] {
        let span = slowest - fastest
        let step = C.bulletTickSteps.first { span / $0 <= Double(C.bulletMaximumTicks) } ?? C.bulletTickSteps.last ?? span
        let first = (fastest / step).rounded(.up) * step
        return stride(from: first, through: slowest, by: step).map { GoalBulletTick(seconds: $0, text: tickText($0)) }
    }

    static func tickText(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        guard total >= 3_600, total % 60 == 0 else { return WorkoutFormat.clock(seconds) }
        return String(format: "%d:%02d", total / 3_600, (total % 3_600) / 60)
    }

    static func gapText(raceDay: Double?, goal: Double?) -> String? {
        guard let raceDay, let goal else { return nil }
        let difference = (raceDay - goal).rounded()
        if difference == 0 { return C.bulletGoalReached }
        let amount = duration(abs(difference))
        return difference > 0 ? String(format: C.bulletGapBehind, amount) : String(format: C.bulletGapAhead, amount)
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return total < 60 ? "\(total) s" : WorkoutFormat.clock(Double(total))
    }
}
