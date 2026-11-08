import Foundation
import Narrative
import WorkoutAnalysis

extension WorkoutReading {
    static func resolve(stored: Data?, assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) -> WorkoutReading {
        let template = TemplateNarrator().narrative(assessment, blocks: blocks, evolution: evolution)
        guard let stored,
              let narrative = try? JSONDecoder().decode(WorkoutNarrative.self, from: stored),
              narrative.factsKey == template.factsKey,
              narrative.findings.count == template.findings.count,
              (narrative.evolution == nil) == (template.evolution == nil) else {
            return WorkoutReading(findings: template.findings, evolution: template.evolution, findingsOnDevice: false, evolutionOnDevice: false)
        }
        let onDevice = narrative.generatedBy == NarrativeConstants.foundationModelsSource
        return WorkoutReading(
            findings: narrative.findings,
            evolution: narrative.evolution,
            findingsOnDevice: onDevice && !narrative.findings.isEmpty,
            evolutionOnDevice: onDevice && narrative.evolution != nil
        )
    }
}
