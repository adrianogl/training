import Insights
import Testing
@testable import trAIning

@Suite struct MorningStrengthTextTests {
    private func workout(adjustments: [StrengthAdjustment] = [], empty: Bool = false) -> GeneratedStrengthWorkout {
        let exercise = GeneratedExercise(exerciseId: "dead-bug", name: "Dead bug", category: "CORE", exerciseName: nil, sets: 3, reps: 10, seconds: nil, restSeconds: 30, weight: nil, perSide: false)
        return GeneratedStrengthWorkout(weekday: 2, group: .core, intensity: .light, minutes: 25, place: .home, exercises: empty ? [] : Array(repeating: exercise, count: 6), adjustments: adjustments)
    }

    @Test func mentionsTrainerWorkout() {
        #expect(MorningStrengthText.line(mfitTitle: nil, trainer: workout()) == "Força: mobilidade e core, 18 min.")
    }

    @Test func flagsAdjustedWorkout() {
        #expect(MorningStrengthText.line(mfitTitle: nil, trainer: workout(adjustments: [.lowReadiness(score: 42)]))?.hasPrefix("Força ajustada:") == true)
        #expect(MorningStrengthText.line(mfitTitle: nil, trainer: workout(adjustments: [.pain([.knee])]))?.hasPrefix("Força:") == true)
    }

    @Test func mentionsMFITAndSkipsRestDays() {
        #expect(MorningStrengthText.line(mfitTitle: "MMII", trainer: workout(empty: true)) == "Força: MMII.")
        #expect(MorningStrengthText.line(mfitTitle: nil, trainer: nil) == nil)
    }
}
