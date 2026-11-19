import Testing
import TrainingCore
@testable import Insights

@Suite struct StrengthGeneratorTests {
    private func session(_ group: TrainerStrengthGroup, _ intensity: TrainerStrengthIntensity = .moderate, minutes: Int = 45, place: StrengthPlace = .gym) -> TrainerStrengthSession {
        TrainerStrengthSession(weekday: 2, group: group, legLoad: StrengthSessions.legLoad(group: group, intensity: intensity), name: "x", source: .trainer, intensity: intensity, minutes: minutes, place: place)
    }

    @Test func fitsTheChosenDurationWithCatalogExercises() {
        for group in TrainerStrengthGroup.allCases {
            for place in StrengthPlace.allCases {
                for minutes in [25, 45, 60] {
                    for intensity in TrainerStrengthIntensity.allCases {
                        let workout = StrengthGenerator.workout(for: session(group, intensity, minutes: minutes, place: place), context: StrengthContext())
                        #expect(abs(workout.estimatedMinutes - Double(minutes)) <= 5, "\(group) \(place) \(minutes) \(intensity): \(workout.estimatedMinutes)")
                        #expect(workout.exercises.allSatisfy { StrengthCatalog.exercise($0.exerciseId) != nil })
                        #expect(Set(workout.exercises.map(\.exerciseId)).count == workout.exercises.count)
                    }
                }
            }
        }
    }

    @Test func qualityDayTurnsLegsIntoMobilityAndCore() {
        let workout = StrengthGenerator.workout(for: session(.lower, .heavy), context: StrengthContext(runKind: .threshold))
        #expect(workout.group == .core)
        #expect(workout.adjustments.contains(.qualityDay(original: .lower)))
        let upper = StrengthGenerator.workout(for: session(.upper), context: StrengthContext(runKind: .long))
        #expect(upper.group == .upper)
    }

    @Test func recoveryWeekCutsVolume() {
        let normal = StrengthGenerator.workout(for: session(.lower), context: StrengthContext())
        let recovery = StrengthGenerator.workout(for: session(.lower), context: StrengthContext(isRecoveryWeek: true))
        #expect(recovery.totalSets < normal.totalSets)
        #expect(recovery.adjustments.contains(.recoveryWeek))
    }

    @Test func raceWeekOnlyMobilityAndNothingCloseToTheRace() {
        let close = StrengthGenerator.workout(for: session(.lower), context: StrengthContext(daysToRace: 2))
        #expect(close.exercises.isEmpty)
        #expect(close.adjustments.contains(.raceRest))
        let week = StrengthGenerator.workout(for: session(.lower), context: StrengthContext(daysToRace: 5))
        #expect(week.exercises.allSatisfy { StrengthCatalog.exercise($0.exerciseId)?.isMobility == true })
        #expect(week.adjustments.contains(.raceWeek))
    }

    @Test func lowReadinessBecomesMobilityUnlessKept() {
        let low = StrengthGenerator.workout(for: session(.lower), context: StrengthContext(readiness: 42))
        #expect(low.exercises.allSatisfy { StrengthCatalog.exercise($0.exerciseId)?.isMobility == true })
        #expect(low.adjustments.contains(.lowReadiness(score: 42)))
        let kept = StrengthGenerator.workout(for: session(.lower), context: StrengthContext(readiness: 42, keepOriginal: true))
        #expect(kept.group == .lower)
        #expect(kept.adjustments.isEmpty)
    }

    @Test func painRemovesExercisesThatLoadTheRegion() {
        let workout = StrengthGenerator.workout(for: session(.lower), context: StrengthContext(pain: [.calfAchilles]))
        #expect(workout.exercises.allSatisfy { StrengthCatalog.exercise($0.exerciseId)?.loads.contains(.calfAchilles) == false })
        #expect(workout.adjustments.contains(.pain([.calfAchilles])))
    }

    @Test func painEverywhereFallsBackToMobility() {
        let workout = StrengthGenerator.workout(for: session(.lower, place: .bodyweight), context: StrengthContext(pain: Set(BodyRegion.allCases)))
        #expect(!workout.exercises.isEmpty)
        #expect(workout.exercises.allSatisfy { StrengthCatalog.exercise($0.exerciseId)?.loads.isEmpty == true })
    }

    @Test func complementsWhatMFITAlreadyWorked() {
        let covered: Set<MovementPattern> = [.antiExtension, .mobilityThoracic]
        let workout = StrengthGenerator.workout(for: session(.core, .light, minutes: 25, place: .home), context: StrengthContext(coveredPatterns: covered))
        let firstThree = workout.exercises.prefix(3).compactMap { StrengthCatalog.exercise($0.exerciseId)?.pattern }
        #expect(firstThree.allSatisfy { !covered.contains($0) })
    }

    @Test func swapReplacesTheExercise() {
        let base = StrengthGenerator.workout(for: session(.core, .light, minutes: 25, place: .home), context: StrengthContext())
        let first = base.exercises[0].exerciseId
        let alternatives = StrengthGenerator.alternatives(for: first, in: base, context: StrengthContext())
        #expect(!alternatives.isEmpty && alternatives.count <= 3)
        #expect(alternatives.allSatisfy { $0.pattern == StrengthCatalog.exercise(first)?.pattern && $0.id != first })
        let swapped = StrengthGenerator.workout(for: session(.core, .light, minutes: 25, place: .home), context: StrengthContext(swaps: [first: alternatives[0].id]))
        #expect(swapped.exercises[0].exerciseId == alternatives[0].id)
        #expect(swapped.exercises[0].replacedName == StrengthCatalog.exercise(first)?.name)
    }

    @Test func progressionAddsLoadOnlyWhenAllSetsWereDone() {
        #expect(StrengthProgression.next(StrengthLoadRecord(weight: 60, completedAllSets: true)) == 62)
        #expect(StrengthProgression.next(StrengthLoadRecord(weight: 20, completedAllSets: true)) == 21)
        #expect(StrengthProgression.next(StrengthLoadRecord(weight: 60, completedAllSets: false)) == 60)
        #expect(StrengthProgression.next(nil) == nil)
        let main = StrengthGenerator.workout(for: session(.lower, .heavy), context: StrengthContext()).exercises[0].exerciseId
        let workout = StrengthGenerator.workout(for: session(.lower, .heavy), context: StrengthContext(loads: [main: StrengthLoadRecord(weight: 60, completedAllSets: true)]))
        #expect(workout.exercises.first { $0.exerciseId == main }?.weight == 62)
    }

    @Test func heavyLowerAtTheGymStartsWithABarbellSquat() {
        let first = StrengthGenerator.workout(for: session(.lower, .heavy), context: StrengthContext()).exercises[0]
        let exercise = StrengthCatalog.exercise(first.exerciseId)
        #expect(exercise?.pattern == .squat)
        #expect(exercise?.equipment == .barbell)
        #expect(first.exerciseName?.isEmpty == false)
    }

    @Test func choiceStaysWithinABlockAndRotatesAcrossBlocks() {
        let ids = { (block: Int) in StrengthGenerator.workout(for: session(.lower, .heavy), context: StrengthContext(block: block)).exercises.map(\.exerciseId) }
        #expect(ids(0) == ids(0))
        #expect(Set((0..<6).map(ids)).count > 1)
    }

    @Test func blockChangesEveryFourWeeks() {
        let monday = Day(year: 2026, month: 11, day: 16)
        #expect(StrengthGenerator.block(for: monday) == StrengthGenerator.block(for: monday.adding(days: 6)))
        #expect(StrengthGenerator.block(for: Day(year: 2026, month: 1, day: 5)) == 0)
        #expect(StrengthGenerator.block(for: Day(year: 2026, month: 2, day: 2)) == 1)
        #expect(StrengthGenerator.block(for: Day(year: 2025, month: 12, day: 29)) == -1)
    }

    @Test func prefersSimpleExercisesOverCombos() {
        for block in 0..<8 {
            let workout = StrengthGenerator.workout(for: session(.fullBody, .moderate), context: StrengthContext(block: block))
            for exercise in workout.exercises {
                let tokens = (exercise.exerciseName ?? "").split(separator: "_")
                #expect(!tokens.contains("TO") && !tokens.contains("AND"), "\(exercise.exerciseId)")
            }
        }
    }

    @Test func legacySwapStillApplies() {
        let base = StrengthGenerator.workout(for: session(.core, .light, minutes: 25, place: .home), context: StrengthContext())
        let first = base.exercises[0].exerciseId
        let swapped = StrengthGenerator.workout(
            for: session(.core, .light, minutes: 25, place: .home), context: StrengthContext(swaps: [first: "dead-bug"])
        )
        #expect(first == "HIP_STABILITY/DEAD_BUG" || swapped.exercises[0].exerciseId == "HIP_STABILITY/DEAD_BUG")
    }
}
