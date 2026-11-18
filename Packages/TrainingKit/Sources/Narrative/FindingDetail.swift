import Foundation
import WorkoutAnalysis

public enum FindingDetail {
    private typealias C = FindingDetailConstants
    private typealias Format = NarrativeFormat

    public static func evidence(_ finding: Finding, blocks: [WorkoutBlock]) -> String? {
        let facts = finding.facts
        let parts: [String?]
        switch finding.kind {
        case .blockInTarget:
            return inTargetValues(blocks)
        case .steadyPace:
            guard let fastest = clock(facts[FindingFact.fastestPace]), let slowest = clock(facts[FindingFact.slowestPace]) else { return nil }
            let range = "\(C.lapsFrom) \(fastest) \(C.to) \(slowest) \(NarrativeConstants.paceUnit)"
            return facts[FindingFact.flatAdjusted] == 1 ? "\(C.onLevel), \(range)" : range
        case .lowerHeartRateThanBefore:
            guard let now = facts[FindingFact.heartRate], let before = facts[FindingFact.beforeHeartRate] else { return nil }
            parts = ["\(Format.integer(now)) bpm \(C.versus) \(Format.integer(before)) bpm", Format.pace(metersPerSecond: facts[FindingFact.speed])]
        case .goodRecovery:
            guard let peak = facts[FindingFact.peak], let recovered = facts[FindingFact.recovered] else { return nil }
            return "\(C.peak) \(Format.integer(peak)) bpm → \(C.average) \(Format.integer(recovered)) bpm"
        case .blockOffTarget:
            parts = offTargetEvidence(finding, blocks: blocks)
        case .stepIncomplete:
            guard let progress = TemplateNarrator.incompleteProgress(finding, blocks: blocks) else { return nil }
            return "\(progress.done) \(C.of) \(progress.target) · \(progress.percent)%"
        case .paceFade:
            guard let last = clock(facts[FindingFact.lastPace]), let middle = clock(facts[FindingFact.medianPace]) else { return nil }
            guard facts[FindingFact.flatAdjusted] == 1, let raw = clock(facts[FindingFact.pace]) else {
                return "\(C.lastLap) \(last) · \(C.median) \(middle) \(NarrativeConstants.paceUnit)"
            }
            let climb = "+\(Format.integer(facts[FindingFact.lastClimb])) m"
            return "\(C.lastLap) \(raw) (\(climb)) · \(C.onLevel) \(last) · \(C.medianOnLevel) \(middle) \(NarrativeConstants.paceUnit)"
        case .climbSlower, .descentFaster:
            return Format.elevationSegment(facts)
        case .weatherSlower:
            guard let pace = clock(facts[FindingFact.pace]), let mild = clock(facts[FindingFact.mildPace]) else { return nil }
            return "\(pace) → \(mild) \(NarrativeConstants.paceUnit) · \(Format.weather(facts))"
        case .cardiacDrift:
            return "FC \(Format.integer(facts[FindingFact.fromHR])) → \(Format.integer(facts[FindingFact.toHR])) bpm · +\(Format.percent(facts[FindingFact.rise]))"
        case .zoneAboveTarget:
            parts = [Format.pace(metersPerSecond: facts[FindingFact.speed]), facts[FindingFact.heartRate].map { "FC \(Format.integer($0)) bpm" }]
        case .hardOnLowReadiness:
            return "\(C.readiness) \(Format.integer(facts[FindingFact.readiness])) \(C.of) 100 · \(C.limit) \(AnalysisConstants.lowReadiness)"
        case .highAcuteChronic:
            return "\(C.ratio) \(Format.decimal(facts[FindingFact.ratio])) · \(C.limit) \(Format.decimal(AnalysisConstants.highAcuteChronic))"
        }
        let text = parts.compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    public static func why(_ finding: Finding, blocks: [WorkoutBlock]) -> String {
        let facts = finding.facts
        switch finding.kind {
        case .blockInTarget:
            return facts[FindingFact.inTarget] == facts[FindingFact.total] ? C.whyAllInTarget : C.whySomeInTarget
        case .steadyPace: return facts[FindingFact.flatAdjusted] == 1 ? C.whySteadyLevel : C.whySteadyPace
        case .lowerHeartRateThanBefore: return C.whyLowerHeartRate
        case .goodRecovery: return C.whyGoodRecovery
        case .blockOffTarget: return offTargetWhy(finding, blocks: blocks)
        case .stepIncomplete:
            return incompleteWhy(finding, blocks: blocks)
        case .paceFade:
            let base = facts[FindingFact.flatAdjusted] == 1 ? C.whyPaceFadeLevel : C.whyPaceFade
            return Format.hasWeather(facts) ? base + String(format: C.whyPaceFadeWeatherFormat, Format.weather(facts)) : base
        case .climbSlower: return String(format: C.whyClimbFormat, clock(facts[FindingFact.flatPace]) ?? "")
        case .descentFaster: return String(format: C.whyDescentFormat, clock(facts[FindingFact.flatPace]) ?? "")
        case .cardiacDrift:
            return Format.hasWeather(facts) ? String(format: C.whyCardiacDriftWeatherFormat, Format.weather(facts)) : C.whyCardiacDrift
        case .weatherSlower:
            let format = facts[FindingFact.cold] == 1 ? C.whyColdSlowerFormat : C.whyHeatSlowerFormat
            return String(format: format, Format.weather(facts), Format.weatherPercent(facts), clock(facts[FindingFact.mildPace]) ?? "")
        case .zoneAboveTarget: return C.whyZoneAbove
        case .hardOnLowReadiness: return C.whyLowReadiness
        case .highAcuteChronic: return C.whyAcuteChronic
        }
    }

    private static func incompleteWhy(_ finding: Finding, blocks: [WorkoutBlock]) -> String {
        let facts = finding.facts
        if Format.status(finding, blocks: blocks) == .notExecuted { return C.whyNotExecuted }
        let signals = slowdownSentences(facts) + pauseSentences(facts) + dayContextSentences(facts)
        if !signals.isEmpty { return signals.joined(separator: " ") }
        guard let target = facts[FindingFact.targetDistance], let done = facts[FindingFact.distance], target > done else { return C.whyIncomplete }
        return String(format: C.whyRemainingFormat, Format.distanceText(target - done))
    }

    private static func slowdownSentences(_ facts: [String: Double]) -> [String] {
        let rise = facts[FindingFact.heartRateRise].map { Format.integer($0) }
        guard let kilometer = facts[FindingFact.fadeKilometer].map({ Format.integer($0) }), let slowdown = facts[FindingFact.slowdown] else {
            return rise.map { [String(format: C.heartRateRiseFormat, $0)] } ?? []
        }
        let held = String(format: C.slowdownFormat, kilometer - 1, Format.integer(slowdown), kilometer)
        return [rise.map { held + String(format: C.slowdownHeartRateFormat, $0) + "." } ?? held + "."]
    }

    private static func pauseSentences(_ facts: [String: Double]) -> [String] {
        guard let count = facts[FindingFact.pauseCount].map({ Format.integer($0) }), let kilometer = facts[FindingFact.pauseKilometer],
              let seconds = facts[FindingFact.pauseSeconds] else { return [] }
        let start = WorkoutFormat.kilometers(kilometer * NarrativeConstants.metersPerKilometer)
        let total = Format.duration(seconds)
        return [count == 1 ? String(format: C.pauseOneFormat, start, total) : String(format: C.pauseManyFormat, count, start, total)]
    }

    private static func dayContextSentences(_ facts: [String: Double]) -> [String] {
        [
            facts[FindingFact.readiness].map { String(format: C.dayReadinessFormat, Format.integer($0)) },
            facts[FindingFact.ratio].map { String(format: C.dayRatioFormat, Format.decimal($0)) },
        ].compactMap { $0 }
    }

    private static func clock(_ seconds: Double?) -> String? {
        seconds.flatMap { $0 > 0 ? WorkoutFormat.clock($0) : nil }
    }

    private static func inTargetValues(_ blocks: [WorkoutBlock]) -> String? {
        let inTarget = blocks.filter { $0.kind == .active && $0.status == .inTarget }
        guard !inTarget.isEmpty else { return nil }
        let usesHeartRate = inTarget.allSatisfy { block in
            if case .heartRateBpm = block.prescribed?.target { return true }
            return false
        }
        if usesHeartRate {
            let values = inTarget.compactMap(\.avgHeartRate).map(String.init)
            return values.isEmpty ? nil : values.joined(separator: " · ") + " bpm"
        }
        let values = inTarget.compactMap { Format.paceClock(metersPerSecond: $0.avgSpeed) }
        return values.isEmpty ? nil : values.joined(separator: " · ") + " \(NarrativeConstants.paceUnit)"
    }

    private static func offTargetEvidence(_ finding: Finding, blocks: [WorkoutBlock]) -> [String?] {
        let facts = finding.facts
        let heartRate = facts[FindingFact.heartRate].map { "FC \(Format.integer($0)) bpm" }
        let pace = Format.pace(metersPerSecond: facts[FindingFact.speed])
        if TemplateNarrator.isHeartRateTarget(NarrativeFormat.status(finding, blocks: blocks)) {
            return [heartRate, TemplateNarrator.heartRateRange(facts).map { "\(C.target) \($0)" }, pace]
        }
        return [pace, TemplateNarrator.paceRange(facts).map { "\(C.target) \($0)" }, heartRate]
    }

    private static func offTargetWhy(_ finding: Finding, blocks: [WorkoutBlock]) -> String {
        let facts = finding.facts
        switch NarrativeFormat.status(finding, blocks: blocks) {
        case .faster:
            return C.whyFaster
        case .aboveTarget:
            return C.whyHeartRateAbove
        case .belowTarget:
            return C.whyHeartRateBelow
        default:
            guard let recovery = facts[FindingFact.recoveryHeartRate] else { return C.whySlower }
            let bpm = Format.integer(recovery)
            return facts[FindingFact.recoveryHighest] == 1
                ? String(format: C.whySlowerHighestRecovery, bpm)
                : String(format: C.whySlowerAfterRecovery, bpm)
        }
    }
}
