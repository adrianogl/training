import CryptoKit
import Foundation
import WorkoutAnalysis

public enum NarrativeFacts {
    public static func key(_ assessment: WorkoutAssessment, blocks: [WorkoutBlock], evolution: EvolutionFacts?) -> String {
        let groups = [assessment.positives.count, assessment.negatives.count, assessment.attention.count].map(String.init)
        let text = NarrativePrompt.text(assessment.orderedFindings, blocks: blocks, evolution: evolution)
            + "\n" + groups.joined(separator: "/")
        return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
