import Foundation
import Metrics

private typealias C = DetailedAnalysisConstants
private typealias K = DetailedEvidenceKey
private typealias T = DetailedAnalysisText

func detailedRecommendations(_ context: DetailedContext) -> [DetailedRecommendation] {
    let rules: [DetailedRecommendation?] = [
        startPaceRecommendation(context), fuelRecommendation(context), swapDayRecommendation(context), easeWeekRecommendation(context),
    ]
    return Array(rules.compactMap { $0 }.prefix(C.maxRecommendations))
}

private func startPaceRecommendation(_ context: DetailedContext) -> DetailedRecommendation? {
    guard context.kind == .long, let fade = context.current.fadeKm, fade < C.earlyFadeKm, let start = context.current.startPace else { return nil }
    let steady = context.similar.compactMap { run -> Double? in
        guard let runStart = run.startPace, !(run.fadeKm.map { $0 < C.earlyFadeKm } ?? false) else { return nil }
        return runStart
    }
    guard let target = median(steady), start < target else { return nil }
    return DetailedRecommendation(
        kind: .startPace,
        title: String(format: T.startRecommendation, C.startKm, DetailedFormat.pace(target)),
        reason: String(format: T.startReason, C.earlyFadeKm, C.startKm, DetailedFormat.pace(target), DetailedFormat.pace(start)),
        number: target
    )
}

private func fuelRecommendation(_ context: DetailedContext) -> DetailedRecommendation? {
    guard let fade = context.current.fadeKm else { return nil }
    let km = max(1, fade - 1)
    var reason = String(format: T.fuelReason, fade)
    if let similar = median(context.similar.compactMap { $0.fadeKm.map(Double.init) }) {
        reason += String(format: T.fuelSimilar, DetailedFormat.whole(similar))
    }
    return DetailedRecommendation(kind: .fuel, title: String(format: T.fuelRecommendation, km), reason: reason, number: Double(km))
}

private func swapDayRecommendation(_ context: DetailedContext) -> DetailedRecommendation? {
    guard let groups = readinessGroups(context), groups.today < C.lowReadiness,
          let low = average(groups.low), let high = average(groups.high), low < high else { return nil }
    return DetailedRecommendation(
        kind: .swapDay,
        title: String(format: T.readinessRecommendation, C.lowReadiness),
        reason: String(format: T.readinessReason, C.lowReadiness, DetailedFormat.whole(low), DetailedFormat.whole(high)),
        number: low
    )
}

private func easeWeekRecommendation(_ context: DetailedContext) -> DetailedRecommendation? {
    guard let load = weekLoad(context), load.percent >= C.heavyWeekPercent else { return nil }
    return DetailedRecommendation(
        kind: .easeWeek,
        title: T.weekRecommendation,
        reason: String(format: T.weekReason, DetailedFormat.kilometers(load.lastKm), DetailedFormat.whole(load.percent)),
        number: load.percent
    )
}
