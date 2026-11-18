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
            let total = Format.integer(facts[FindingFact.total])
            guard total > 1 else { return ["o bloco ativo dentro do alvo prescrito"] }
            return ["\(Format.integer(facts[FindingFact.inTarget])) de \(total) blocos ativos dentro do alvo prescrito"]
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
            return [state, "feito \(progress.done) de \(progress.target) prescritos (\(progress.percent)%)"]
        case .paceFade:
            let fade = "última volta \(Format.integer(facts[FindingFact.fade])) s/km mais lenta que a mediana"
            return Format.hasWeather(facts) ? [fade, "calor de \(Format.weather(facts))"] : [fade]
        case .cardiacDrift:
            let drift = [
                "a FC subiu \(Format.percent(facts[FindingFact.rise]))",
                "de \(Format.integer(facts[FindingFact.fromHR])) bpm para \(Format.integer(facts[FindingFact.toHR])) bpm",
                "com o pace estável",
            ]
            return Format.hasWeather(facts) ? drift + ["esperada com \(Format.weather(facts))"] : drift
        case .windAgainst:
            let calm = facts[FindingFact.mildPace].map { WorkoutFormat.clock($0) } ?? ""
            return [
                "\(Format.kilometerRange(facts)) com vento contra de \(Format.windSpeed(facts[FindingFact.headwind]))",
                "\(calm)\(NarrativeConstants.paceUnit) sem o vento",
            ]
        case .runFormFade:
            return [Format.formEvidence(facts) ?? "", "forma caindo no fim"]
        case .weatherSlower:
            let pace = facts[FindingFact.pace].map { WorkoutFormat.clock($0) } ?? ""
            let mild = facts[FindingFact.mildPace].map { WorkoutFormat.clock($0) } ?? ""
            return [
                "pace \(pace)\(NarrativeConstants.paceUnit) com \(Format.weather(facts))",
                "\(mild)\(NarrativeConstants.paceUnit) \(NarrativeConstants.mildClimate)",
                "ritmo \(Format.weatherPercent(facts)) mais lento pelo clima",
            ]
        case .zoneAboveTarget:
            return ["Z\(Format.integer(facts[FindingFact.zone]))", "bloco leve"]
        case .climbSlower, .descentFaster:
            let level = facts[FindingFact.flatPace].map { WorkoutFormat.clock($0) } ?? ""
            return [Format.elevationSegment(facts), "\(level)\(NarrativeConstants.paceUnit) no equivalente no plano"]
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
