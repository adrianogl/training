import SwiftUI
import WorkoutAnalysis

struct GoalBulletChart: View {
    let today: Double?
    let raceDay: Double?
    let goal: Double?
    var todayLabel = TodayConstants.bulletToday
    var raceDayLabel = TodayConstants.bulletRaceDay

    private typealias C = TodayConstants

    var showsGap = false

    var body: some View {
        let values = [today, raceDay, goal].compactMap { $0 }
        if let low = values.min(), let high = values.max() {
            let span = max(high - low, C.bulletRulerSpan)
            let padding = span * C.bulletPaddingRatio
            let fastest = (low + high) / 2 - span / 2 - padding
            let slowest = (low + high) / 2 + span / 2 + padding
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let x = { (seconds: Double) in (slowest - seconds) / (slowest - fastest) * width }
                    ruler(width: width, x: x, fastest: fastest, slowest: slowest)
                }
                .frame(height: C.bulletRulerHeight)
                if showsGap, let gap = GoalBulletLayout.gapText(raceDay: raceDay, goal: goal) {
                    Text(gap).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
    }

    @ViewBuilder
    private func ruler(width: Double, x: @escaping (Double) -> Double, fastest: Double, slowest: Double) -> some View {
        let trackY = C.bulletRulerTrackY
        let todayBelow = today.flatMap { value in goal.map { abs(x(value) - x($0)) < C.bulletLabelGap } } ?? false
        ZStack(alignment: .topLeading) {
            Capsule().fill(BrandColors.track)
                .frame(width: width, height: 4)
                .position(x: width / 2, y: trackY)
            ForEach(GoalBulletLayout.ticks(fastest: fastest, slowest: slowest), id: \.seconds) { tick in
                Rectangle().fill(BrandColors.line)
                    .frame(width: 1, height: C.bulletTickHeight)
                    .position(x: x(tick.seconds), y: trackY)
                if goal.map({ abs(x($0) - x(tick.seconds)) >= C.bulletTickGoalGap }) ?? true {
                    Text(tick.text).font(.caption2).foregroundStyle(BrandColors.dim).fixedSize()
                        .position(x: clamp(x(tick.seconds), width), y: C.bulletTickLabelY)
                }
            }
            if let today, let raceDay {
                Capsule().fill(BrandColors.race.opacity(0.35))
                    .frame(width: abs(x(raceDay) - x(today)), height: 4)
                    .position(x: (x(raceDay) + x(today)) / 2, y: trackY)
            }
            if let goal {
                RoundedRectangle(cornerRadius: 2).fill(BrandColors.accent)
                    .frame(width: 4, height: 24)
                    .position(x: x(goal), y: trackY)
                valueLabel(C.bulletGoal, WorkoutFormat.clock(goal), color: BrandColors.accent)
                    .position(x: clamp(x(goal), width), y: C.bulletAboveY)
            }
            if let today {
                Circle().fill(BrandColors.text).frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(BrandColors.background, lineWidth: 2))
                    .position(x: x(today), y: trackY)
            }
            if let raceDay {
                Circle().fill(BrandColors.race).frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(BrandColors.background, lineWidth: 2))
                    .position(x: x(raceDay), y: trackY)
            }
            labels(width: width, x: x, todayBelow: todayBelow)
        }
    }

    @ViewBuilder
    private func labels(width: Double, x: (Double) -> Double, todayBelow: Bool) -> some View {
        if todayBelow, let today, let raceDay, WorkoutFormat.clock(today) == WorkoutFormat.clock(raceDay) {
            valueLabel("\(todayLabel) \(C.bulletAnd) \(raceDayLabel)", WorkoutFormat.clock(raceDay), color: BrandColors.race)
                .position(x: clamp(x(raceDay), width), y: C.bulletBelowY)
        } else if todayBelow {
            let positions = Self.labelPositions(today: today.map(x), raceDay: raceDay.map(x), width: width)
            if let today, let position = positions.today {
                valueLabel(todayLabel, WorkoutFormat.clock(today), color: BrandColors.text).position(x: position, y: C.bulletBelowY)
            }
            if let raceDay, let position = positions.raceDay {
                valueLabel(raceDayLabel, WorkoutFormat.clock(raceDay), color: BrandColors.race).position(x: position, y: C.bulletBelowY)
            }
        } else {
            if let today {
                valueLabel(todayLabel, WorkoutFormat.clock(today), color: BrandColors.text)
                    .position(x: clamp(x(today), width), y: C.bulletAboveY)
            }
            if let raceDay {
                valueLabel(raceDayLabel, WorkoutFormat.clock(raceDay), color: BrandColors.race)
                    .position(x: clamp(x(raceDay), width), y: C.bulletBelowY)
            }
        }
    }

    private func valueLabel(_ title: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(BrandColors.dim)
            Text(value).font(BrandFonts.number(15)).foregroundStyle(color)
        }
        .fixedSize()
    }

    private func clamp(_ x: Double, _ width: Double) -> Double {
        Self.clamp(x, width)
    }

    private static func clamp(_ x: Double, _ width: Double) -> Double {
        min(max(x, C.bulletLabelInset), width - C.bulletLabelInset)
    }

    static func labelPositions(today: Double?, raceDay: Double?, width: Double) -> (today: Double?, raceDay: Double?) {
        guard let today, let raceDay else {
            return (today.map { clamp($0, width) }, raceDay.map { clamp($0, width) })
        }
        let first = clamp(today, width)
        let second = clamp(raceDay, width)
        guard abs(first - second) < C.bulletLabelGap else { return (first, second) }
        let todayIsLeft = today <= raceDay
        let middle = min(max((first + second) / 2, C.bulletLabelInset + C.bulletLabelGap / 2), width - C.bulletLabelInset - C.bulletLabelGap / 2)
        let left = middle - C.bulletLabelGap / 2
        let right = middle + C.bulletLabelGap / 2
        return todayIsLeft ? (left, right) : (right, left)
    }

    private var accessibilityText: String {
        [today.map { "Previsão de hoje \(WorkoutFormat.clock($0))" },
         raceDay.map { "no dia da prova \(WorkoutFormat.clock($0))" },
         goal.map { "meta \(WorkoutFormat.clock($0))" }]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
