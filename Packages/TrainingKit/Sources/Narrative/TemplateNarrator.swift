import Foundation
import WorkoutAnalysis

public struct TemplateNarrator: Narrator {
    public init() {}

    public func narrate(_ assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) async -> WorkoutNarrative {
        narrative(assessment, blocks: blocks, evolution: evolution)
    }

    public func narrative(_ assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) -> WorkoutNarrative {
        WorkoutNarrative(
            findings: assessment.orderedFindings.map { Self.text($0, blocks: blocks) },
            evolution: evolution.map(Self.evolution),
            generatedBy: NarrativeConstants.templateSource,
            factsKey: NarrativeFacts.key(assessment, blocks: blocks, evolution: evolution)
        )
    }

    public static func evolution(_ facts: EvolutionFacts) -> String {
        let parts = evolutionParts(facts)
        guard let heartRate = parts.heartRate else { return "\(parts.pace) \(parts.since)." }
        return "\(parts.pace), \(heartRate), \(parts.since)."
    }

    static func evolutionParts(_ facts: EvolutionFacts) -> EvolutionParts {
        let paceSeconds = Int(abs(facts.paceDelta).rounded())
        let pace: String
        if abs(facts.paceDelta) < NarrativeConstants.paceDeltaThreshold {
            pace = "Mesmo pace"
        } else {
            pace = facts.paceDelta < 0 ? "\(paceSeconds) s/km mais rápido" : "\(paceSeconds) s/km mais lento"
        }
        let since = "em relação a \(facts.oldestDate.trimmingCharacters(in: CharacterSet(charactersIn: ".")))"
        guard let heartRateDelta = facts.heartRateDelta else { return EvolutionParts(pace: pace, heartRate: nil, since: since) }
        let beats = Int(abs(heartRateDelta).rounded())
        let heartRate: String
        if abs(heartRateDelta) < NarrativeConstants.heartRateDeltaThreshold {
            heartRate = "FC igual"
        } else {
            heartRate = heartRateDelta < 0 ? "FC \(beats) bpm menor" : "FC \(beats) bpm maior"
        }
        return EvolutionParts(pace: pace, heartRate: heartRate, since: since)
    }

    public static func text(_ finding: Finding, blocks: [WorkoutBlock]) -> String {
        typealias Format = NarrativeFormat
        let facts = finding.facts
        let label = Format.label(finding, blocks: blocks) ?? NarrativeConstants.genericBlock
        switch finding.kind {
        case .blockInTarget:
            let inTarget = Format.integer(facts[FindingFact.inTarget])
            let total = Format.integer(facts[FindingFact.total])
            return inTarget == total
                ? "Todos os blocos ativos dentro do alvo prescrito: \(inTarget) de \(total)."
                : "\(inTarget) de \(total) blocos ativos dentro do alvo prescrito."
        case .steadyPace:
            return "\(label) com pace constante: \(Format.integer(facts[FindingFact.spread])) s/km de diferença entre as voltas."
        case .lowerHeartRateThanBefore:
            return "\(label) com FC \(Format.integer(facts[FindingFact.delta])) bpm menor que da última vez, no mesmo pace."
        case .goodRecovery:
            return "\(label): a FC caiu \(Format.integer(facts[FindingFact.drop])) bpm desde o pico do bloco anterior."
        case .blockOffTarget:
            return offTarget(finding, label: label, blocks: blocks)
        case .stepIncomplete:
            return incomplete(finding, label: label, blocks: blocks)
        case .paceFade:
            return "\(label) perdeu ritmo no fim: a última volta saiu \(Format.integer(facts[FindingFact.fade])) s/km mais lenta que a mediana."
        case .cardiacDrift:
            let rise = Format.percent(facts[FindingFact.rise])
            return "\(label) com desacoplamento: a FC subiu \(rise) (\(Format.integer(facts[FindingFact.fromHR])) → \(Format.integer(facts[FindingFact.toHR])) bpm) com o pace estável."
        case .zoneAboveTarget:
            return "\(label) em Z\(Format.integer(facts[FindingFact.zone])), acima do esperado para um bloco leve."
        case .hardOnLowReadiness:
            return "Treino forte num dia de prontidão baixa: \(Format.integer(facts[FindingFact.readiness])) de 100."
        case .highAcuteChronic:
            return "Carga aguda:crônica alta: \(Format.decimal(facts[FindingFact.ratio]))."
        }
    }

    static func offTargetDirection(_ status: BlockStatus?) -> String {
        switch status {
        case .aboveTarget: "acima do alvo"
        case .belowTarget: "abaixo do alvo"
        case .slower: "mais lento que o prescrito"
        case .faster: "mais rápido que o prescrito"
        default: "fora do alvo prescrito"
        }
    }

    static func isHeartRateTarget(_ status: BlockStatus?) -> Bool {
        status == .aboveTarget || status == .belowTarget
    }

    static func heartRateRange(_ facts: [String: Double]) -> String? {
        guard let low = facts[FindingFact.targetLow], let high = facts[FindingFact.targetHigh] else { return nil }
        return "\(NarrativeFormat.integer(low))–\(NarrativeFormat.integer(high)) bpm"
    }

    static func paceRange(_ facts: [String: Double]) -> String? {
        guard let low = facts[FindingFact.targetLow], let high = facts[FindingFact.targetHigh],
              let fast = NarrativeFormat.paceClock(metersPerSecond: high),
              let slow = NarrativeFormat.paceClock(metersPerSecond: low) else { return nil }
        return "\(fast)–\(slow) \(NarrativeConstants.paceUnit)"
    }

    private static func offTarget(_ finding: Finding, label: String, blocks: [WorkoutBlock]) -> String {
        let facts = finding.facts
        let status = NarrativeFormat.status(finding, blocks: blocks)
        let direction = offTargetDirection(status)
        if isHeartRateTarget(status) {
            let heartRate = facts[FindingFact.heartRate].map { "\(NarrativeFormat.integer($0)) bpm" } ?? NarrativeConstants.unknown
            guard let range = heartRateRange(facts) else { return "\(label) com FC \(direction): \(heartRate)." }
            return "\(label) com FC \(direction): \(heartRate) para \(range)."
        }
        let pace = NarrativeFormat.pace(metersPerSecond: facts[FindingFact.speed]) ?? NarrativeConstants.unknown
        guard let range = paceRange(facts) else { return "\(label) \(direction): \(pace)." }
        return "\(label) \(direction): \(pace) para \(range)."
    }

    static func incompleteState(_ finding: Finding, blocks: [WorkoutBlock]) -> String {
        NarrativeFormat.status(finding, blocks: blocks) == .notExecuted ? "não executado" : "não completado"
    }

    static func incompleteProgress(_ finding: Finding, blocks: [WorkoutBlock]) -> (done: String, target: String)? {
        let facts = finding.facts
        let notExecuted = NarrativeFormat.status(finding, blocks: blocks) == .notExecuted
        if let target = facts[FindingFact.targetDistance] {
            return (NarrativeFormat.distance(notExecuted ? 0 : facts[FindingFact.distance] ?? 0), NarrativeFormat.distance(target))
        }
        if let target = facts[FindingFact.targetSeconds] {
            return (WorkoutFormat.clock(notExecuted ? 0 : facts[FindingFact.seconds] ?? 0), WorkoutFormat.clock(target))
        }
        return nil
    }

    private static func incomplete(_ finding: Finding, label: String, blocks: [WorkoutBlock]) -> String {
        let state = incompleteState(finding, blocks: blocks)
        guard let progress = incompleteProgress(finding, blocks: blocks) else { return "\(label) \(state)." }
        return "\(label) \(state): \(progress.done) de \(progress.target)."
    }
}
