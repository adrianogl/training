import Testing
import TrainingCore
@testable import Insights

@Suite struct StrengthTests {
    @Test func countsSetsPerMuscleWithHalfForSecondary() {
        let sets = StrengthMuscles.sets([("SQUAT", 3), ("HIP_RAISE", 4), ("UNKNOWN", 5)])

        #expect(sets[.quads] == 3)
        #expect(sets[.glutes] == 7)
        #expect(sets[.hamstrings] == 2)
        #expect(sets[.lowerBack] == 1.5)
        #expect(sets[.chest] == nil)
    }

    @Test func levelsFollowTheSessionAndWeekScales() {
        #expect(StrengthMuscles.level(0, scale: .session) == 0)
        #expect(StrengthMuscles.level(2, scale: .session) == 1)
        #expect(StrengthMuscles.level(6, scale: .session) == 2)
        #expect(StrengthMuscles.level(12, scale: .session) == 3)
        #expect(StrengthMuscles.level(6, scale: .week) == 1)
        #expect(StrengthMuscles.level(15, scale: .week) == 3)
    }

    @Test func legDayNeedsMostSetsOnLegs() {
        #expect(StrengthMuscles.isLegDay([("SQUAT", 3)]))
        #expect(StrengthMuscles.isLegDay([("HIP_RAISE", 4), ("LEG_CURL", 3), ("PLANK", 3)]))
        #expect(!StrengthMuscles.isLegDay([("CALF_RAISE", 3), ("BENCH_PRESS", 6), ("TRICEPS_EXTENSION", 4)]))
        #expect(!StrengthMuscles.isLegDay([("DEADLIFT", 3), ("ROW", 6), ("PULL_UP", 4)]))
        #expect(!StrengthMuscles.isLegDay([]))
    }

    @Test func weeklyCountsCoverTheLastWeeksEndingThisWeek() {
        let today = Day(year: 2026, month: 11, day: 18)
        let days = [Day(year: 2026, month: 11, day: 16), Day(year: 2026, month: 11, day: 18), Day(year: 2026, month: 11, day: 11), Day(year: 2026, month: 10, day: 1)]

        let counts = StrengthHistory.weeklyCounts(days, weeks: 4, today: today)

        #expect(counts == [0, 0, 1, 2])
        #expect(StrengthHistory.average(counts.dropLast()) == 1.0 / 3.0)
    }

    @Test func warnsWhenQualityOrLongFollowsLegStrength() {
        let monday = Day(year: 2026, month: 11, day: 16)
        let days = (0..<7).map { offset in
            StrengthWeekDay(day: monday.adding(days: offset), run: [1: .threshold, 3: .easy, 6: .long][offset], legs: [0, 5].contains(offset))
        }

        let warnings = StrengthWeek.legWarnings(days)

        #expect(warnings == ["Limiar no dia seguinte à força de pernas de segunda.", "Longão no dia seguinte à força de pernas de sábado."])
    }
}
