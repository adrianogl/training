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
    var original: [PlannedStep]?

    var body: some View {
        let aligned = original.map { PlanText.aligned(steps, original: $0) } ?? steps.map { _ in nil }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 { Divider().overlay(BrandColors.line) }
                let before = aligned[index]
                if step.children.isEmpty {
                    row(step, original: before, prefix: nil, wasPrefix: nil)
                } else {
                    ForEach(Array(step.children.enumerated()), id: \.offset) { childIndex, child in
                        let first = childIndex == 0
                        row(
                            child,
                            original: before?.children.indices.contains(childIndex) == true ? before?.children[childIndex] : nil,
                            prefix: first ? String(format: TodayConstants.planRepeatFormat, step.repeats) : nil,
                            wasPrefix: first ? before.flatMap { PlanText.wasRepeats(step, original: $0) } : nil
                        )
                    }
                }
            }
        }
    }

    private func row(_ step: PlannedStep, original: PlannedStep?, prefix: String?, wasPrefix: String?) -> some View {
        let was = original.flatMap { PlanText.was(step, original: $0) }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(BrandColors.zone(PlanText.level(step))).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: TodayConstants.dayAdjustWasSpacing) {
                Text([prefix, TodayConstants.planStepNames[step.kind]].compactMap { $0 }.joined(separator: " "))
                    .font(.footnote)
                    .foregroundStyle(BrandColors.text)
                if let wasPrefix { wasText(wasPrefix) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: TodayConstants.dayAdjustWasSpacing) {
                if was == nil {
                    Text(PlanText.detail(step)).font(.footnote).foregroundStyle(BrandColors.dim).monospacedDigit()
                } else {
                    emphasized(step)
                }
                if let was { wasText(was) }
            }
        }
        .padding(.vertical, 6)
    }

    private func emphasized(_ step: PlannedStep) -> some View {
        let parts = PlanText.detailParts(step)
        let lead = Text(parts.lead.map { $0 + TodayConstants.dayAdjustDetailSeparator } ?? "").foregroundStyle(BrandColors.dim)
        let target = Text(parts.target ?? "").foregroundStyle(BrandColors.text).fontWeight(.semibold)
        return Text("\(lead)\(target)").font(.footnote).monospacedDigit()
    }

    private func wasText(_ text: String) -> some View {
        Text(text).font(.caption2).foregroundStyle(BrandColors.dim).monospacedDigit()
    }
}

struct TodayGarminPlanContent: View {
    let plan: PlannedWorkout
    let display: DayAdjustDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(PlanText.title(plan.title)).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            if let single = PlanText.singleStep(display.steps) {
                HStack(alignment: .firstTextBaseline) {
                    Text(single.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Spacer()
                    VStack(alignment: .trailing, spacing: TodayConstants.dayAdjustWasSpacing) {
                        Text(single.detail).font(.subheadline).foregroundStyle(BrandColors.dim).monospacedDigit()
                        if let was = singleWas {
                            Text(was).font(.caption2).foregroundStyle(BrandColors.dim).monospacedDigit()
                        }
                    }
                }
            } else {
                PlannedShape(steps: display.steps).frame(height: TodayConstants.planShapeHeight)
                PlannedStepsList(steps: display.steps, original: display.original)
            }
            if let notice = display.notice {
                DSNotice(tone: .attention, title: notice.title, text: notice.text) {
                    DSFlowLayout(spacing: TodayConstants.dayAdjustChipSpacing) {
                        ForEach(notice.chips, id: \.self) { DSChip(text: $0, tone: .attention) }
                    }
                }
            } else if let fallback = display.fallback {
                DSNotice(tone: .attention, title: TodayConstants.planAdjustTitle, text: fallback)
            }
        }
    }

    private var singleWas: String? {
        guard let original = display.original,
              let step = display.steps.flatMap(\.flattened).first,
              let before = original.flatMap(\.flattened).first else { return nil }
        return PlanText.was(step, original: before)
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
        let parts = detailParts(step)
        return [parts.lead, parts.target].compactMap { $0 }.joined(separator: TodayConstants.dayAdjustDetailSeparator)
    }

    static func detailParts(_ step: PlannedStep) -> (lead: String?, target: String?) {
        var parts: [String] = []
        if let seconds = step.seconds { parts.append(String(format: TodayConstants.planMinutesFormat, Int((seconds / 60).rounded()))) }
        if let meters = step.meters { parts.append(distance(meters)) }
        return (parts.isEmpty ? nil : parts.joined(separator: TodayConstants.dayAdjustDetailSeparator), target(step))
    }

    static func was(_ step: PlannedStep, original: PlannedStep) -> String? {
        var parts: [String] = []
        if step.meters != original.meters, let meters = original.meters { parts.append(distance(meters)) }
        if step.target != original.target, let target = original.target {
            if case .pace(let fastest, let slowest) = target {
                parts.append(DayAdjustText.range(fastest: fastest, slowest: slowest))
            } else if let text = self.target(original) {
                parts.append(text)
            }
        }
        guard !parts.isEmpty else { return nil }
        return String(format: TodayConstants.dayAdjustWasFormat, parts.joined(separator: TodayConstants.dayAdjustDetailSeparator))
    }

    static func wasRepeats(_ step: PlannedStep, original: PlannedStep) -> String? {
        guard step.repeats != original.repeats else { return nil }
        return String(format: TodayConstants.dayAdjustWasFormat, String(format: TodayConstants.planRepeatFormat, original.repeats))
    }

    static func aligned(_ steps: [PlannedStep], original: [PlannedStep]) -> [PlannedStep?] {
        func same(_ lhs: PlannedStep, _ rhs: PlannedStep) -> Bool { lhs.kind == rhs.kind && lhs.children.count == rhs.children.count }
        let limit = min(steps.count, original.count)
        let prefix = (0..<limit).first { !same(steps[$0], original[$0]) } ?? limit
        let suffix = (0..<(limit - prefix)).first { !same(steps[steps.count - 1 - $0], original[original.count - 1 - $0]) } ?? (limit - prefix)
        return steps.indices.map { index in
            if index < prefix { return original[index] }
            if index >= steps.count - suffix { return original[original.count - (steps.count - index)] }
            return nil
        }
    }

    static func adjusted(_ plan: PlannedWorkout, steps: [PlannedStep]) -> PlannedWorkout {
        var result = plan
        let before = plan.steps.flatMap(\.flattened).compactMap(\.meters).reduce(0, +)
        let after = steps.flatMap(\.flattened).compactMap(\.meters).reduce(0, +)
        result.steps = steps
        result.estimatedMeters = plan.estimatedMeters.map { $0 - before + after }
        return result
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
        let activeBlocks = PlannedStep.activeBlocks(plan.steps)
        if hasRepeat || activeBlocks > 1 { return .intervals }
        let meters = plan.estimatedMeters ?? plan.steps.flatMap(\.flattened).compactMap(\.meters).reduce(0, +)
        return isLongRun(name: plan.title, distanceMeters: meters, goalKm: nil) ? .long : .continuous
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
