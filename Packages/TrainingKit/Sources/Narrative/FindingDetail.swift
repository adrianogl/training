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
            return "\(C.lapsFrom) \(fastest) \(C.to) \(slowest) \(NarrativeConstants.paceUnit)"
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
            return "\(C.done) \(progress.done) \(C.of) \(progress.target)"
        case .paceFade:
            guard let last = clock(facts[FindingFact.lastPace]), let middle = clock(facts[FindingFact.medianPace]) else { return nil }
            return "\(C.lastLap) \(last) · \(C.median) \(middle) \(NarrativeConstants.paceUnit)"
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
        case .steadyPace: return C.whySteadyPace
        case .lowerHeartRateThanBefore: return C.whyLowerHeartRate
        case .goodRecovery: return C.whyGoodRecovery
        case .blockOffTarget: return offTargetWhy(finding, blocks: blocks)
        case .stepIncomplete:
            return NarrativeFormat.status(finding, blocks: blocks) == .notExecuted ? C.whyNotExecuted : C.whyIncomplete
        case .paceFade: return C.whyPaceFade
        case .cardiacDrift: return C.whyCardiacDrift
        case .zoneAboveTarget: return C.whyZoneAbove
        case .hardOnLowReadiness: return C.whyLowReadiness
        case .highAcuteChronic: return C.whyAcuteChronic
        }
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
