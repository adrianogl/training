import WorkoutAnalysis

enum NarrativePrompt {
    static func text(_ findings: [Finding], blocks: [WorkoutBlock], evolution: EvolutionFacts?) -> String {
        let lines = findings.enumerated().map { index, finding in
            let group = NarrativeConstants.groupNames[finding.group] ?? finding.group.rawValue
            let kind = NarrativeConstants.kindNames[finding.kind] ?? finding.kind.rawValue
            let block = NarrativeFormat.label(finding, blocks: blocks).map { " no bloco \($0)" } ?? NarrativeConstants.wholeWorkout
            return "Achado \(index + 1), \(group): \(kind)\(block). Fatos: \(facts(finding, blocks: blocks).joined(separator: ", "))."
        }
        return (lines + ["\(NarrativeConstants.evolutionHeader) \(evolutionText(evolution))."]).joined(separator: "\n")
    }

    private static func evolutionText(_ evolution: EvolutionFacts?) -> String {
        guard let evolution else { return NarrativeConstants.noEvolution }
        let parts = TemplateNarrator.evolutionParts(evolution)
        return [parts.pace.lowercased(), parts.heartRate, parts.since].compactMap { $0 }.joined(separator: ", ")
    }

    private static func facts(_ finding: Finding, blocks: [WorkoutBlock]) -> [String] {
        typealias Format = NarrativeFormat
        let facts = finding.facts
        switch finding.kind {
        case .blockInTarget:
            return ["\(Format.integer(facts[FindingFact.inTarget])) de \(Format.integer(facts[FindingFact.total])) blocos ativos dentro do alvo prescrito"]
        case .steadyPace:
            return ["\(Format.integer(facts[FindingFact.spread])) s/km de diferença entre as voltas"]
        case .lowerHeartRateThanBefore:
            return ["a FC ficou \(Format.integer(facts[FindingFact.delta])) bpm menor que da última vez", "mesmo pace"]
        case .goodRecovery:
            return ["a FC caiu \(Format.integer(facts[FindingFact.drop])) bpm desde o pico do bloco anterior"]
        case .blockOffTarget:
            return offTarget(finding, blocks: blocks)
        case .stepIncomplete:
            let state = TemplateNarrator.incompleteState(finding, blocks: blocks)
            guard let progress = TemplateNarrator.incompleteProgress(finding, blocks: blocks) else { return [state] }
            return [state, "feito \(progress.done) de \(progress.target) prescritos"]
        case .paceFade:
            return ["última volta \(Format.integer(facts[FindingFact.fade])) s/km mais lenta que a mediana"]
        case .cardiacDrift:
            return [
                "a FC subiu \(Format.percent(facts[FindingFact.rise]))",
                "de \(Format.integer(facts[FindingFact.fromHR])) bpm para \(Format.integer(facts[FindingFact.toHR])) bpm",
                "com o pace estável",
            ]
        case .zoneAboveTarget:
            return ["Z\(Format.integer(facts[FindingFact.zone]))", "bloco leve"]
        case .hardOnLowReadiness:
            return ["treino forte", "prontidão \(Format.integer(facts[FindingFact.readiness])) de 100"]
        case .highAcuteChronic:
            return ["carga aguda:crônica \(Format.decimal(facts[FindingFact.ratio]))"]
        }
    }

    private static func offTarget(_ finding: Finding, blocks: [WorkoutBlock]) -> [String] {
        let facts = finding.facts
        let status = NarrativeFormat.status(finding, blocks: blocks)
        let direction = TemplateNarrator.offTargetDirection(status)
        if TemplateNarrator.isHeartRateTarget(status) {
            let heartRate = facts[FindingFact.heartRate].map { "FC \(NarrativeFormat.integer($0)) bpm" }
            let range = TemplateNarrator.heartRateRange(facts).map { "alvo \($0)" }
            return [heartRate, range, "FC \(direction)"].compactMap { $0 }
        }
        let pace = NarrativeFormat.pace(metersPerSecond: facts[FindingFact.speed]).map { "pace \($0)" }
        let range = TemplateNarrator.paceRange(facts).map { "alvo \($0)" }
        return [pace, range, direction].compactMap { $0 }
    }
}
