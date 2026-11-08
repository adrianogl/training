import Foundation
import Narrative
import WorkoutAnalysis

extension WorkoutReading {
    static func resolve(stored: Data?, assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) -> WorkoutReading {
        let template = TemplateNarrator().narrative(assessment, blocks: blocks, evolution: evolution)
        guard let stored,
              let narrative = try? JSONDecoder().decode(WorkoutNarrative.self, from: stored),
              narrative.findings.count == template.findings.count else {
            return WorkoutReading(findings: template.findings, evolution: template.evolution, findingsOnDevice: false, evolutionOnDevice: false)
        }
        let onDevice = narrative.generatedBy == NarrativeConstants.foundationModelsSource
        let storedEvolution = evolution == nil ? nil : narrative.evolution
        return WorkoutReading(
            findings: narrative.findings,
            evolution: storedEvolution ?? template.evolution,
            findingsOnDevice: onDevice && !narrative.findings.isEmpty,
            evolutionOnDevice: onDevice && storedEvolution != nil
        )
    }
}
