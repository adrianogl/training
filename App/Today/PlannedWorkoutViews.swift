import GarminAPI
import Metrics
import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct PlannedShape: View {
    let steps: [PlannedStep]

    var body: some View {
        let flat = steps.flatMap(\.flattened)
        let weights = flat.map(PlanText.weight)
        let total = max(weights.reduce(0, +), 1)
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(Array(flat.enumerated()), id: \.offset) { index, step in
                    let level = PlanText.level(step)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(BrandColors.zone(level))
                        .frame(width: max(1.5, proxy.size.width * weights[index] / total - 1.5), height: proxy.size.height * Double(level) / 5)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

struct PlannedStepsList: View {
    let steps: [PlannedStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 { Divider().overlay(BrandColors.line) }
                if step.children.isEmpty {
                    row(step, prefix: nil)
                } else {
                    ForEach(Array(step.children.enumerated()), id: \.offset) { childIndex, child in
                        row(child, prefix: childIndex == 0 ? String(format: TodayConstants.planRepeatFormat, step.repeats) : nil)
                    }
                }
            }
        }
    }

    private func row(_ step: PlannedStep, prefix: String?) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(BrandColors.zone(PlanText.level(step))).frame(width: 10, height: 10)
            Text([prefix, TodayConstants.planStepNames[step.kind]].compactMap { $0 }.joined(separator: " "))
                .font(.footnote)
                .foregroundStyle(BrandColors.text)
            Spacer()
            Text(PlanText.detail(step)).font(.footnote).foregroundStyle(BrandColors.dim).monospacedDigit()
        }
        .padding(.vertical, 6)
    }
}

enum PlanText {
    static func estimate(_ plan: PlannedWorkout, fallback: PaceBand?) -> String? {
        if let range = PlannedTimeEstimate.total(plan, fallback: fallback) {
            let time = RunTimeText.range(range)
            guard let meters = plan.estimatedMeters, meters > 0 else { return time }
            return String(format: RunTimeConstants.distanceAndTimeFormat, TodayText.decimal(meters / WorkoutConstants.metersPerKilometer, fractionDigits: 1), time)
        }
        guard let meters = plan.estimatedMeters, let seconds = plan.estimatedSeconds else { return nil }
        return String(format: TodayConstants.planEstimateFormat, TodayText.decimal(meters / WorkoutConstants.metersPerKilometer, fractionDigits: 1), WorkoutFormat.clock(seconds))
    }

    static func detail(_ step: PlannedStep) -> String {
        var parts: [String] = []
        if let seconds = step.seconds { parts.append(String(format: TodayConstants.planMinutesFormat, Int((seconds / 60).rounded()))) }
        if let meters = step.meters { parts.append(distance(meters)) }
        if let target = target(step) { parts.append(target) }
        return parts.joined(separator: " · ")
    }

    static func target(_ step: PlannedStep) -> String? {
        switch step.target {
        case .pace(let fastest, let slowest): "\(WorkoutFormat.clock(fastest))–\(WorkoutFormat.clock(slowest))\(WorkoutConstants.paceUnit)"
        case .heartRate(let low, let high): String(format: TodayConstants.planHeartRateFormat, Int(low), Int(high))
        case .zone(let zone): String(format: TodayConstants.planZoneFormat, zone)
        case nil: nil
        }
    }

    static func distance(_ meters: Double) -> String {
        guard meters >= WorkoutConstants.metersPerKilometer else { return String(format: TodayConstants.planMetersFormat, Int(meters.rounded())) }
        let km = meters / WorkoutConstants.metersPerKilometer
        return String(format: TodayConstants.planKilometersFormat, TodayText.decimal(km, fractionDigits: km.rounded() == km ? 0 : 1))
    }

    static func title(_ title: String) -> String {
        let trimmed = title.replacingOccurrences(of: TodayConstants.planTitleDatePattern, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? title : trimmed
    }

    static func singleStep(_ steps: [PlannedStep]) -> (name: String, detail: String)? {
        let flat = steps.flatMap(\.flattened)
        guard flat.count == 1, let step = flat.first, let meters = step.meters else { return nil }
        return (String(format: TodayConstants.planContinuousFormat, distance(meters)), target(step) ?? "")
    }

    static func shape(_ plan: PlannedWorkout) -> PlannedWorkoutShape {
        let hasRepeat = plan.steps.contains { $0.repeats > 1 || !$0.children.isEmpty }
        let activeBlocks = plan.steps.flatMap(\.flattened).filter { $0.kind == .active }.count
        if hasRepeat || activeBlocks > 1 { return .intervals }
        let meters = plan.estimatedMeters ?? plan.steps.flatMap(\.flattened).compactMap(\.meters).reduce(0, +)
        return isLongRun(name: plan.title, distanceMeters: meters, goalKm: nil) ? .long : .continuous
    }

    static func adjust(_ verdict: ReadinessVerdict, shape: PlannedWorkoutShape) -> String? {
        switch verdict {
        case .hard: TodayConstants.planAdjustHard
        case .moderate: TodayConstants.planAdjustModerate[shape]
        case .rest: TodayConstants.planAdjustRest[shape]
        }
    }

    static func level(_ step: PlannedStep) -> Int {
        if case .zone(let zone) = step.target { return min(max(zone, 1), 5) }
        return TodayConstants.planShapeLevels[step.kind] ?? 2
    }

    static func weight(_ step: PlannedStep) -> Double {
        if let seconds = step.seconds { return seconds }
        guard let meters = step.meters else { return 60 }
        let pace: Double
        if case .pace(let fastest, let slowest) = step.target { pace = (fastest + slowest) / 2 } else { pace = TodayConstants.planShapeDefaultPace }
        return meters / WorkoutConstants.metersPerKilometer * pace
    }
}
