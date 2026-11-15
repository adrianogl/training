import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerRotationTextTests {
    private static let day = Day(iso: "2026-11-17")!

    private static func workout(
        _ kind: TrainerDayKind, title: String, meters: Double, steps: [TrainerStep] = [], variant: TrainerVariant?,
        method: TrainerMethod? = nil
    ) -> TrainerWorkout {
        TrainerWorkout(
            day: day, kind: kind, title: title, totalMeters: meters, steps: steps, paceLow: 290, paceHigh: 304, rationale: "",
            method: method, variant: variant
        )
    }

    private func texts(_ line: TrainerDayLine) -> [String] {
        [line.title, line.detail] + line.tags.map(\.text)
    }

    @Test func listingShowsOnlyTheWorkoutType() {
        let strides = Self.workout(.easy, title: "Rodagem 10 km + 6 × 100 m", meters: 10_000, steps: [
            TrainerStep(kind: .steady, meters: 9_400, paceLow: 290, paceHigh: 304),
            TrainerStep(kind: .work, repeats: 6, meters: 100, paceLow: 220, paceHigh: 226),
            TrainerStep(kind: .recovery, repeats: 5, meters: 0, restSeconds: 60),
        ], variant: .strides)
        let medium = Self.workout(.easy, title: "Média-longa 14 km", meters: 14_000, variant: .mediumLong)
        let fartlek = Self.workout(.optionalEasy, title: "Fartlek 6 × 500 m", meters: 9_000, variant: .fartlek)
        let long = Self.workout(.long, title: "Longão 20 km progressivo", meters: 20_000, variant: .progressiveLong)

        #expect(texts(TrainerText.dayLine(strides)) == ["Rodagem · 10 km", "4:50–5:04/km"])
        #expect(texts(TrainerText.dayLine(medium)) == ["Média-longa · 14 km", "4:50–5:04/km"])
        #expect(texts(TrainerText.dayLine(fartlek)) == ["Fartlek · 9 km", "4:50–5:04/km", "opcional"])
        #expect(texts(TrainerText.dayLine(long)) == ["Longão · 20 km", "4:50–5:04/km"])
    }

    @Test func progressiveThresholdGroupsTheBlocksInTheListing() {
        let steps = [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, meters: 2_000, paceLow: 250, paceHigh: 256, method: .cruiseIntervals),
            TrainerStep(kind: .recovery, meters: 0, restSeconds: 120),
            TrainerStep(kind: .work, meters: 2_000, paceLow: 245, paceHigh: 251, method: .cruiseIntervals),
            TrainerStep(kind: .recovery, meters: 0, restSeconds: 120),
            TrainerStep(kind: .work, meters: 2_000, paceLow: 240, paceHigh: 246, method: .cruiseIntervals),
        ]
        var workout = Self.workout(.threshold, title: "Limiar progressivo 3 × 2 km", meters: 9_000, steps: steps, variant: .progressiveThreshold)
        workout.paceLow = 240
        workout.paceHigh = 256

        #expect(texts(TrainerText.dayLine(workout)) == ["Limiar · 9 km", "3 × 2 km a 4:00–4:16"])
    }

    @Test func detailStepsNameHillsStridesAndFartlek() {
        let hills = Self.workout(.vo2max, title: "Subidas 8 × 200 m", meters: 6_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_000),
            TrainerStep(kind: .work, repeats: 8, meters: 200, method: .intervals),
            TrainerStep(kind: .recovery, repeats: 7, meters: 200),
        ], variant: .hills, method: .intervals)
        let fartlek = Self.workout(.optionalEasy, title: "Fartlek 6 × 500 m", meters: 9_000, steps: [
            TrainerStep(kind: .warmup, meters: 3_500, paceLow: 290, paceHigh: 304),
            TrainerStep(kind: .work, repeats: 6, meters: 500, paceLow: 250, paceHigh: 256),
            TrainerStep(kind: .recovery, repeats: 5, meters: 500, paceLow: 290, paceHigh: 304),
        ], variant: .fartlek)

        #expect(TrainerText.stepRows(hills).map(\.title) == ["Aquecimento", "8×", "Subida", "Trote"])
        #expect(TrainerText.stepRows(fartlek).map(\.title) == ["Aquecimento", "6×", "Forte", "Recuperação"])
    }
}
