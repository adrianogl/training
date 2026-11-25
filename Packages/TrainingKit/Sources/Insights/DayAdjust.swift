import Foundation
import GarminAPI
import TrainingCore

private typealias C = DayAdjustConstants

public enum DayAdjust {
    public static func adjust(_ input: DayAdjustInput) -> DayAdjustResult {
        guard let factors = factors(
            score: input.score, temperature: input.temperature, dewPoint: input.dewPoint, radiation: input.radiation,
            hotSessions: input.hotSessions, heavyLegs: input.heavyLegs
        ) else { return .rest }
        let total: Int
        let reasons: [DayAdjustReason]
        switch decide(factors, meanPaces: activePaces(in: input.plan.steps)) {
        case let .swap(list): return .swap(reasons: list)
        case let .apply(seconds, list):
            total = seconds
            reasons = list
        }

        var steps = input.plan.steps
        var didShorten = false
        if factors.shorten {
            steps = shortened(steps, shape: input.shape)
            didShorten = steps != input.plan.steps
        }
        if total == 0, !didShorten { return .none }

        steps = steps.map { shifted($0, fixed: factors.fixedSeconds, heatShare: factors.heatShare) }

        return .adjusted(steps: steps, original: input.plan.steps, seconds: total, reasons: reasons, shortened: didShorten)
    }

    public static func factors(
        score: Int?, temperature: Double?, dewPoint: Double?, radiation: Double?, hotSessions: Int, heavyLegs: Bool
    ) -> DayAdjustFactors? {
        if let score, score < C.restBelow { return nil }
        var readinessSeconds = 0
        var shorten = false
        if let score {
            readinessSeconds = C.readinessSteps.first { score >= $0.minimum }?.seconds ?? 0
            shorten = readinessSeconds == C.readinessSteps.map(\.seconds).max()
        }
        var heatShare: Double?
        if let temperature, let dewPoint {
            heatShare = WeatherAdjustment.heatShare(temperature: temperature, dewPoint: dewPoint, radiation: radiation, hotSessions: hotSessions)
        }
        return DayAdjustFactors(
            score: score, readinessSeconds: readinessSeconds, shorten: shorten, temperature: temperature, dewPoint: dewPoint,
            heatShare: heatShare, legsSeconds: heavyLegs ? C.heavyLegsSeconds : 0
        )
    }

    public static func decide(_ factors: DayAdjustFactors, meanPaces: [Double]) -> DayAdjustDecision {
        var reasons: [DayAdjustReason] = []
        if let score = factors.score, factors.readinessSeconds > 0 {
            reasons.append(.readiness(score: score, seconds: factors.readinessSeconds))
        }
        var heatSeconds = 0
        if let share = factors.heatShare, let temperature = factors.temperature, let dewPoint = factors.dewPoint {
            heatSeconds = meanPaces.map { heatOffset($0, share: share) }.max() ?? 0
            if heatSeconds > 0 {
                reasons.append(.heat(temperature: temperature, dewPoint: dewPoint, seconds: heatSeconds))
            }
        } else {
            reasons.append(.noForecast)
        }
        if factors.legsSeconds > 0 {
            reasons.append(.heavyLegs(seconds: factors.legsSeconds))
        }
        let total = factors.fixedSeconds + heatSeconds
        if total > C.maximumSeconds { return .swap(reasons: reasons) }
        return .apply(seconds: total, reasons: reasons)
    }

    public static func heatOffset(_ meanPace: Double, share: Double) -> Int {
        let seconds = Int((share * meanPace).rounded())
        return seconds < RunWeatherConstants.minimumHeatSeconds ? 0 : seconds
    }

    public static func weather(
        at hour: Int, in hours: [(hour: Int, temperature: Double, dewPoint: Double?)]
    ) -> (temperature: Double, dewPoint: Double?)? {
        closestIndex(to: hour, in: hours.map(\.hour)).map { (hours[$0].temperature, hours[$0].dewPoint) }
    }

    public static func closestIndex(to hour: Int, in hours: [Int]) -> Int? {
        hours.indices.min { lhs, rhs in
            let left = abs(hours[lhs] - hour)
            let right = abs(hours[rhs] - hour)
            return left != right ? left < right : hours[lhs] < hours[rhs]
        }
    }

    private static func activePaces(in steps: [PlannedStep]) -> [Double] {
        steps.flatMap { step -> [Double] in
            if !step.children.isEmpty { return activePaces(in: step.children) }
            guard step.kind == .active, case let .pace(fastest, slowest)? = step.target else { return [] }
            return [(fastest + slowest) / 2]
        }
    }

    private static func shifted(_ step: PlannedStep, fixed: Int, heatShare: Double?) -> PlannedStep {
        var result = step
        if !step.children.isEmpty {
            result.children = step.children.map { shifted($0, fixed: fixed, heatShare: heatShare) }
            return result
        }
        guard step.kind == .active, case let .pace(fastest, slowest)? = step.target else { return step }
        let heat = Double(heatOffset((fastest + slowest) / 2, share: heatShare ?? 0))
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
