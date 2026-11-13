import GarminAPI
import Metrics
import SwiftUI
import WorkoutAnalysis

struct TodayPlanCard: View {
    let plan: PlannedWorkout
    let verdict: ReadinessVerdict?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = TodayConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(C.planTitle).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                if let estimate = PlanText.estimate(plan) {
                    Text(estimate).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 20) {
                    summary
                    PlannedStepsList(steps: plan.steps).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                summary
                PlannedStepsList(steps: plan.steps)
            }
        }
        .brandCard()
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(plan.title).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            PlannedShape(steps: plan.steps).frame(height: C.planShapeHeight)
            if let verdict, let advice = C.planAdjust[verdict] {
                VStack(alignment: .leading, spacing: 4) {
                    Text(C.planAdjustTitle).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.attention)
                    Text(advice).font(.footnote).foregroundStyle(BrandColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandColors.attention.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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
    static func estimate(_ plan: PlannedWorkout) -> String? {
        guard let meters = plan.estimatedMeters, let seconds = plan.estimatedSeconds else { return nil }
        return String(format: TodayConstants.planEstimateFormat, TodayText.decimal(meters / WorkoutConstants.metersPerKilometer, fractionDigits: 1), WorkoutFormat.clock(seconds))
    }

    static func detail(_ step: PlannedStep) -> String {
        var parts: [String] = []
        if let seconds = step.seconds { parts.append(String(format: TodayConstants.planMinutesFormat, Int((seconds / 60).rounded()))) }
        if let meters = step.meters { parts.append(String(format: TodayConstants.planMetersFormat, Int(meters.rounded()))) }
        switch step.target {
        case .pace(let fastest, let slowest): parts.append("\(WorkoutFormat.clock(fastest))–\(WorkoutFormat.clock(slowest))\(WorkoutConstants.paceUnit)")
        case .heartRate(let low, let high): parts.append(String(format: TodayConstants.planHeartRateFormat, Int(low), Int(high)))
        case .zone(let zone): parts.append(String(format: TodayConstants.planZoneFormat, zone))
        case nil: break
        }
        return parts.joined(separator: " · ")
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
