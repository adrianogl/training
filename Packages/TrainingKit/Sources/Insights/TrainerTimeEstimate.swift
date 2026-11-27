import Foundation
import TrainingCore

private typealias C = TrainerEngineConstants

extension TrainerEngine {
    public static func easyPaceBand(plan: TrainerPlan?, history: TrainerHistory, today: Day) -> PaceBand? {
        if let paces = plan?.paces { return easyPaceBand(paces) }
        let since = today.adding(days: -C.paceWindowDays)
        guard history.runs.contains(where: { $0.day >= since && $0.day <= today && $0.meters > 0 }) else { return nil }
        return easyPaceBand(paces(history: history, today: today))
    }

    public static func timeEstimate(_ workout: TrainerWorkout, fallback: PaceBand?) -> RunTimeRange? {
        guard workout.kind != .off, workout.totalMeters > 0 else { return nil }
        let easy = workout.steps.first { $0.kind == .warmup }.flatMap(paceBand) ?? fallback
        var parts: [RunTimePart] = []
        var covered = 0.0
        for step in workout.steps {
            let count = Double(max(step.repeats, 0))
            if let rest = step.restSeconds { parts.append(.fixed(seconds: rest * count)) }
            guard step.meters > 0 else { continue }
            let pace = paceBand(step) ?? (step.kind == .recovery ? (step.isStrides ? stridesWalkBand : easy) : nil)
            parts.append(.distance(meters: step.meters * count, pace: pace))
            covered += step.meters * count
        }
        let remaining = workout.totalMeters - covered
        if remaining >= 1 {
            let pace = workout.steps.isEmpty ? band(low: workout.paceLow, high: workout.paceHigh) : easy
            parts.append(.distance(meters: remaining, pace: pace))
        }
        return RunTimeEstimate.total(parts, fallback: fallback)
    }

    static let stridesWalkBand = PaceBand(fastest: C.stridesWalkPaceLow, slowest: C.stridesWalkPaceHigh)

    static func easyPaceBand(_ paces: TrainerPaces) -> PaceBand {
        let range = band(paces.easy, C.easyBand)
        return PaceBand(fastest: range.low, slowest: range.high)
    }

    static func paceBand(_ step: TrainerStep) -> PaceBand? {
        band(low: step.paceLow, high: step.paceHigh)
    }

    static func band(low: Double?, high: Double?) -> PaceBand? {
        guard let low, let high, low > 0, high > 0 else { return nil }
        return PaceBand(fastest: low, slowest: high)
    }
}
