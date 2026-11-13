import SwiftUI
import WorkoutAnalysis

struct GoalBulletChart: View {
    let today: Double?
    let raceDay: Double?
    let goal: Double?

    private typealias C = TodayConstants

    var body: some View {
        let values = [today, raceDay, goal].compactMap { $0 }
        if let low = values.min(), let high = values.max() {
            let span = max(high - low, C.bulletMinimumSpan)
            let padding = span * C.bulletPaddingRatio
            let fastest = (low + high) / 2 - span / 2 - padding
            let slowest = (low + high) / 2 + span / 2 + padding
            GeometryReader { proxy in
                let width = proxy.size.width
                let x = { (seconds: Double) in (slowest - seconds) / (slowest - fastest) * width }
                let trackY = 26.0
                ZStack(alignment: .topLeading) {
                    Capsule().fill(BrandColors.track)
                        .frame(width: width, height: C.bulletTrackHeight)
                        .position(x: width / 2, y: trackY)
                    if let today, let raceDay {
                        Capsule().fill(BrandColors.race.opacity(0.35))
                            .frame(width: abs(x(raceDay) - x(today)), height: C.bulletTrackHeight)
                            .position(x: (x(raceDay) + x(today)) / 2, y: trackY)
                    }
                    if let goal {
                        Capsule().fill(BrandColors.accent)
                            .frame(width: 3, height: 30)
                            .position(x: x(goal), y: trackY)
                        label("\(C.bulletGoal) \(WorkoutFormat.clock(goal))", color: BrandColors.accent, weight: .bold)
                            .position(x: clamp(x(goal), width), y: 4)
                    }
                    if let today {
                        Circle().fill(BrandColors.text).frame(width: 12, height: 12).position(x: x(today), y: trackY)
                        valueLabel(C.bulletToday, WorkoutFormat.clock(today), color: BrandColors.text)
                            .position(x: clamp(x(today), width), y: 60)
                    }
                    if let raceDay {
                        Circle().fill(BrandColors.race).frame(width: 14, height: 14).position(x: x(raceDay), y: trackY)
                        valueLabel(C.bulletRaceDay, WorkoutFormat.clock(raceDay), color: BrandColors.race)
                            .position(x: clamp(x(raceDay), width), y: 60)
                    }
                }
            }
            .frame(height: C.bulletHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
    }

    private func label(_ text: String, color: Color, weight: Font.Weight = .regular) -> some View {
        Text(text).font(.caption.weight(weight)).foregroundStyle(color).fixedSize()
    }

    private func valueLabel(_ title: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(title).font(.caption2).foregroundStyle(BrandColors.dim)
            Text(value).font(BrandFonts.number(15)).foregroundStyle(color)
        }
        .fixedSize()
    }

    private func clamp(_ x: Double, _ width: Double) -> Double {
        min(max(x, 32), width - 32)
    }

    private var accessibilityText: String {
        [today.map { "Previsão de hoje \(WorkoutFormat.clock($0))" },
         raceDay.map { "no dia da prova \(WorkoutFormat.clock($0))" },
         goal.map { "meta \(WorkoutFormat.clock($0))" }]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
