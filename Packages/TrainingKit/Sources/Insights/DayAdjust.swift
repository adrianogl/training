import Foundation
import GarminAPI
import TrainingCore

private typealias C = DayAdjustConstants

public enum DayAdjust {
    public static func adjust(_ input: DayAdjustInput) -> DayAdjustResult {
        if let score = input.score, score < C.restBelow { return .rest }

        var reasons: [DayAdjustReason] = []
        var readinessSeconds = 0
        var shorten = false

        if let score = input.score {
            readinessSeconds = C.readinessSteps.first { score >= $0.minimum }?.seconds ?? 0
            if readinessSeconds > 0 {
                reasons.append(.readiness(score: score, seconds: readinessSeconds))
            }
            shorten = readinessSeconds == C.readinessSteps.map(\.seconds).max()
        }

        let adaptation = WeatherAdjustment.adaptation(hotSessions: input.hotSessions)
        var heatShare = 0.0
        var heatSeconds = 0
        if let temperature = input.temperature, let dewPoint = input.dewPoint {
            heatShare = WeatherAdjustment.heatFactor(temperature: temperature, dewPoint: dewPoint) * (1 - adaptation)
            heatSeconds = activePaces(in: input.plan.steps).map { heatOffset($0, share: heatShare) }.max() ?? 0
            if heatSeconds > 0 {
                reasons.append(.heat(temperature: temperature, dewPoint: dewPoint, seconds: heatSeconds))
            }
        } else {
            reasons.append(.noForecast)
        }

        var legsSeconds = 0
        if input.heavyLegs {
            legsSeconds = C.heavyLegsSeconds
            reasons.append(.heavyLegs(seconds: legsSeconds))
        }

        let total = readinessSeconds + heatSeconds + legsSeconds
        if total > C.maximumSeconds { return .swap(reasons: reasons) }

        var steps = input.plan.steps
        var didShorten = false
        if shorten {
            steps = shortened(steps, shape: input.shape)
            didShorten = steps != input.plan.steps
        }
        if total == 0, !didShorten { return .none }

        let fixed = readinessSeconds + legsSeconds
        steps = steps.map { shifted($0, fixed: fixed, heatShare: heatShare) }

        return .adjusted(steps: steps, original: input.plan.steps, seconds: total, reasons: reasons, shortened: didShorten)
    }

    public static func usualHour(_ starts: [Date], calendar: Calendar) -> Int {
        let hours = starts.map { calendar.component(.hour, from: $0) }.sorted()
        guard !hours.isEmpty else { return C.defaultHour }
        return hours[(hours.count - 1) / 2]
    }

    public static func weather(
        at hour: Int, in hours: [(hour: Int, temperature: Double, dewPoint: Double?)]
    ) -> (temperature: Double, dewPoint: Double?)? {
        let closest = hours.min { lhs, rhs in
            let left = abs(lhs.hour - hour)
            let right = abs(rhs.hour - hour)
            return left != right ? left < right : lhs.hour < rhs.hour
        }
        return closest.map { ($0.temperature, $0.dewPoint) }
    }

    private static func activePaces(in steps: [PlannedStep]) -> [Double] {
        steps.flatMap { step -> [Double] in
            if !step.children.isEmpty { return activePaces(in: step.children) }
            guard step.kind == .active, case let .pace(fastest, slowest)? = step.target else { return [] }
            return [(fastest + slowest) / 2]
        }
    }

    private static func heatOffset(_ meanPace: Double, share: Double) -> Int {
        let seconds = Int((share * meanPace).rounded())
        return seconds < RunWeatherConstants.minimumHeatSeconds ? 0 : seconds
    }

    private static func shifted(_ step: PlannedStep, fixed: Int, heatShare: Double) -> PlannedStep {
        var result = step
        if !step.children.isEmpty {
            result.children = step.children.map { shifted($0, fixed: fixed, heatShare: heatShare) }
            return result
        }
        guard step.kind == .active, case let .pace(fastest, slowest)? = step.target else { return step }
        let heat = Double(heatOffset((fastest + slowest) / 2, share: heatShare))
        let offset = Double(fixed) + heat
        result.target = .pace(fastest: fastest + offset, slowest: slowest + offset)
        return result
    }

    private static func shortened(_ steps: [PlannedStep], shape: DayAdjustShape) -> [PlannedStep] {
        switch shape {
        case .intervals: droppingRepeat(steps)
        case .continuous: scalingActive(steps, onlyLast: false)
        case .long: scalingActive(steps, onlyLast: !PlannedStep.isSplitContinuous(steps))
        }
    }

    private static func droppingRepeat(_ steps: [PlannedStep]) -> [PlannedStep] {
        if let result = droppingNestedRepeat(steps) { return result }
        let actives = steps.indices.filter { steps[$0].kind == .active && steps[$0].children.isEmpty }
        guard actives.count > 1, let last = actives.last else { return steps }
        var result = steps
        result.remove(at: last)
        if last > 0, [.recovery, .rest].contains(result[last - 1].kind) { result.remove(at: last - 1) }
        return result
    }

    private static func droppingNestedRepeat(_ steps: [PlannedStep]) -> [PlannedStep]? {
        for index in steps.indices {
            let step = steps[index]
            guard !step.children.isEmpty, containsActive(step) else { continue }
            var result = steps
            if step.repeats > 1 {
                result[index].repeats -= 1
                return result
            }
            if let children = droppingNestedRepeat(step.children) {
                result[index].children = children
                return result
            }
        }
        return nil
    }

    private static func containsActive(_ step: PlannedStep) -> Bool {
        step.children.contains { $0.kind == .active || containsActive($0) }
    }

    private static func scalingActive(_ steps: [PlannedStep], onlyLast: Bool) -> [PlannedStep] {
        let lastIndex = steps.lastIndex { $0.kind == .active && $0.children.isEmpty }
        return steps.enumerated().map { index, step in
            guard step.kind == .active, step.children.isEmpty, let meters = step.meters else { return step }
            guard !onlyLast || index == lastIndex else { return step }
            var result = step
            result.meters = (meters * C.shortenShare / C.roundingMeters).rounded() * C.roundingMeters
            return result
        }
    }
}
