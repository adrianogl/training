import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct ClaudeStrengthTests {
    private let monday = Day(iso: "2026-11-23")!

    private func json(_ body: String) -> String {
        """
        Aqui está:
        ```json
        { "versao": 1, "autor": "claude", "resumo": "Semana leve", "treinos": [\(body)] }
        ```
        """
    }

    private func day(_ iso: String, _ exercises: String, foco: String = "core", minutos: Int = 25, local: String = "home") -> String {
        #"{ "dia": "\#(iso)", "foco": "\#(foco)", "minutos": \#(minutos), "local": "\#(local)", "porque": "motivo", "exercicios": [\#(exercises)] }"#
    }

    private let mobility = #"{ "id": "mobilidade-90-90", "series": 2, "reps": 8, "descanso": 15 }, { "id": "pallof-elastico", "series": 3, "reps": 10, "descanso": 30 }, { "id": "prancha-lateral", "series": 3, "segundos": 30, "descanso": 30 }, { "id": "dead-bug", "series": 3, "reps": 10, "descanso": 30 }, { "id": "mobilidade-tornozelo", "series": 2, "reps": 8, "descanso": 15 }, { "id": "passaro-cao", "series": 3, "reps": 10, "descanso": 30 }"#

    private func context(runKinds: [Day: TrainerDayKind] = [:], race: Day? = nil, pain: Set<BodyRegion> = [], loads: [String: Double] = [:], home: Set<StrengthEquipment>? = nil) -> ClaudeValidationContext {
        let tuesday = TrainerStrengthSession(weekday: 2, group: .core, legLoad: .light, name: "Mob", source: .trainer, intensity: .light, minutes: 25, place: .home)
        let thursday = TrainerStrengthSession(weekday: 4, group: .lower, legLoad: .heavy, name: "Pernas", source: .trainer, intensity: .heavy, minutes: 45, place: .gym)
        return ClaudeValidationContext(
            today: Day(iso: "2026-11-22")!, first: monday, last: monday.adding(days: 6),
            trainerSessions: [tuesday, thursday], mfitWeekdays: [1, 3, 5], runKinds: runKinds, raceDay: race, pain: pain, lastLoads: loads,
            homeEquipment: home
        )
    }

    @Test func parsesJSONInsideACodeBlock() throws {
        let response = try ClaudeStrengthParser.parse(json(day("2026-11-24", mobility)))
        #expect(response.version == 1)
        #expect(response.workouts.first?.exercises.count == 6)
        #expect(response.workouts.first?.why == "motivo")
    }

    @Test func rejectsUnknownVersionAndBrokenJSON() {
        #expect(throws: ClaudeStrengthParseError.unsupportedVersion(2)) { try ClaudeStrengthParser.parse(#"{ "versao": 2, "treinos": [] }"#) }
        #expect(throws: ClaudeStrengthParseError.invalid) { try ClaudeStrengthParser.parse("sem json aqui") }
    }

    @Test func homeEquipmentDecidesWhatClaudeCanUseAtHome() throws {
        let kettlebell = #"{ "id": "CORE/KETTLEBELL_WINDMILL", "series": 3, "reps": 8, "descanso": 45 }"#
        let response = try ClaudeStrengthParser.parse(json(day("2026-11-24", kettlebell)))
        let blocked = ClaudeStrengthValidator.validate(response, context: context()).first?.errors ?? []
        #expect(blocked.contains(.wrongPlace("CORE/KETTLEBELL_WINDMILL")))
        let allowed = ClaudeStrengthValidator.validate(response, context: context(home: [.kettlebell])).first?.errors ?? []
        #expect(!allowed.contains(.wrongPlace("CORE/KETTLEBELL_WINDMILL")))
    }

    @Test func validDayBecomesAWorkout() throws {
        let result = ClaudeStrengthValidator.validate(try ClaudeStrengthParser.parse(json(day("2026-11-24", mobility))), context: context())
        let first = try #require(result.first)
        #expect(first.errors.isEmpty)
        #expect(first.workout?.exercises.count == 6)
        #expect(first.workout?.group == .core)
        #expect(first.workout?.exercises.first?.perSide == true)
    }

    @Test func blocksDaysThatAreNotTheTrainers() throws {
        let response = try ClaudeStrengthParser.parse(json([
            day("2026-11-22", mobility), day("2026-12-03", mobility), day("2026-11-25", mobility), day("2026-11-28", mobility),
        ].joined(separator: ",")))
        let issues = ClaudeStrengthValidator.validate(response, context: context()).map(\.errors)
        #expect(issues[0].contains(.pastDay))
        #expect(issues[1].contains(.outOfPeriod))
        #expect(issues[2].contains(.mfitDay))
        #expect(issues[3].contains(.notTrainerDay))
    }

    @Test func blocksExercisesOutsideTheCatalogOrPlaceOrWithPain() throws {
        let exercises = #"{ "id": "panturrilha-salto", "series": 3, "reps": 10, "descanso": 30 }, { "id": "agachamento-livre", "series": 3, "reps": 8, "descanso": 90 }, { "id": "panturrilha-degrau", "series": 3, "reps": 12, "descanso": 45 }"#
        let response = try ClaudeStrengthParser.parse(json(day("2026-11-24", exercises)))
        let errors = ClaudeStrengthValidator.validate(response, context: context(pain: [.calfAchilles]))[0].errors
        #expect(errors.contains(.unknownExercise("panturrilha-salto")))
        #expect(errors.contains(.wrongPlace("agachamento-livre")))
        #expect(errors.contains(.painRegion("panturrilha-degrau")))
    }

    @Test func blocksDosesOutOfRange() throws {
        let exercises = #"{ "id": "dead-bug", "series": 9, "reps": 10, "descanso": 30 }, { "id": "prancha", "series": 3, "descanso": 30 }, { "id": "passaro-cao", "series": 3, "reps": 10, "descanso": 600 }"#
        let errors = ClaudeStrengthValidator.validate(try ClaudeStrengthParser.parse(json(day("2026-11-24", exercises))), context: context())[0].errors
        #expect(errors.filter { if case .doseOutOfRange = $0 { true } else { false } }.count == 3)
    }

    @Test func blocksHeavyLegsBeforeQualityAndNearTheRace() throws {
        let legs = #"{ "id": "agachamento-livre", "series": 4, "reps": 6, "descanso": 150 }, { "id": "terra-romeno", "series": 3, "reps": 8, "descanso": 120 }, { "id": "bulgaro-halteres", "series": 3, "reps": 8, "descanso": 90 }, { "id": "panturrilha-em-pe", "series": 3, "reps": 12, "descanso": 60 }"#
        let response = try ClaudeStrengthParser.parse(json(day("2026-11-26", legs, foco: "lower", minutos: 45, local: "gym")))
        let quality = ClaudeStrengthValidator.validate(response, context: context(runKinds: [monday.adding(days: 5): .long]))[0].errors
        #expect(quality.contains(.heavyLegsBeforeQuality))
        let race = ClaudeStrengthValidator.validate(response, context: context(race: monday.adding(days: 5)))[0].errors
        #expect(race.contains(.nearRace))
    }

    @Test func warnsAboutDurationAndLoadJumps() throws {
        let exercises = #"{ "id": "agachamento-livre", "series": 4, "reps": 6, "descanso": 150, "kg": 70 }"#
        let response = try ClaudeStrengthParser.parse(json(day("2026-11-26", exercises, foco: "lower", minutos: 45, local: "gym")))
        let result = ClaudeStrengthValidator.validate(response, context: context(loads: ["agachamento-livre": 60]))[0]
        #expect(result.errors.isEmpty)
        #expect(result.warnings.contains { if case .durationOff = $0 { true } else { false } })
        #expect(result.warnings.contains(.loadJump("agachamento-livre")))
        #expect(result.workout?.exercises.first?.weight == 70)
    }
}

@Suite struct ClaudeStrengthApplyTests {
    private let session = TrainerStrengthSession(weekday: 2, group: .lower, legLoad: .heavy, name: "Pernas", source: .trainer, intensity: .heavy, minutes: 45, place: .gym)

    private func imported() -> GeneratedStrengthWorkout {
        let squat = GeneratedExercise(exerciseId: "agachamento-livre", name: "Agachamento livre", category: "SQUAT", exerciseName: "BARBELL_BACK_SQUAT", sets: 4, reps: 6, seconds: nil, restSeconds: 150, weight: 60, perSide: false)
        let calf = GeneratedExercise(exerciseId: "panturrilha-em-pe", name: "Panturrilha em pé na máquina", category: "CALF_RAISE", exerciseName: nil, sets: 3, reps: 12, seconds: nil, restSeconds: 60, weight: nil, perSide: false)
        return GeneratedStrengthWorkout(weekday: 2, group: .lower, intensity: .heavy, minutes: 45, place: .gym, exercises: [squat, calf], adjustments: [])
    }

    @Test func keepsTheImportedWorkoutOnANormalDay() {
        #expect(ClaudeStrengthApply.apply(imported(), session: session, context: StrengthContext()) == imported())
    }

    @Test func lowReadinessFallsBackToMobilityUnlessKept() {
        let low = ClaudeStrengthApply.apply(imported(), session: session, context: StrengthContext(readiness: 40))
        #expect(low.adjustments.contains(.lowReadiness(score: 40)))
        #expect(low.exercises.allSatisfy { StrengthCatalog.exercise($0.exerciseId)?.isMobility == true })
        #expect(ClaudeStrengthApply.apply(imported(), session: session, context: StrengthContext(readiness: 40, keepOriginal: true)) == imported())
    }

    @Test func raceWeekOverridesTheImport() {
        #expect(ClaudeStrengthApply.apply(imported(), session: session, context: StrengthContext(daysToRace: 2)).exercises.isEmpty)
    }

    @Test func painRemovesTheAffectedExercises() {
        let result = ClaudeStrengthApply.apply(imported(), session: session, context: StrengthContext(pain: [.calfAchilles]))
        #expect(result.exercises.map(\.exerciseId) == ["agachamento-livre"])
        #expect(result.adjustments == [.pain([.calfAchilles])])
    }
}

@Suite struct ClaudeReplacesMFITTests {
    private let mobility = #"{ "id": "mobilidade-90-90", "series": 2, "reps": 8, "descanso": 15 }, { "id": "prancha", "series": 3, "segundos": 30, "descanso": 30 }"#

    private func context() -> ClaudeValidationContext {
        let tuesday = TrainerStrengthSession(weekday: 2, group: .core, legLoad: .light, name: "Mob", source: .trainer, intensity: .light, minutes: 25, place: .home)
        let monday = Day(iso: "2026-11-23")!
        return ClaudeValidationContext(
            today: Day(iso: "2026-11-22")!, first: monday, last: monday.adding(days: 6), trainerSessions: [tuesday],
            mfitWeekdays: [1, 3, 5], runKinds: [:], raceDay: nil, pain: [], lastLoads: [:]
        )
    }

    private func response(replaces: Bool?) throws -> ClaudeStrengthResponse {
        let flag = replaces.map { #", "substitui_mfit": \#($0)"# } ?? ""
        return try ClaudeStrengthParser.parse(#"{ "versao": 1, "treinos": [{ "dia": "2026-11-25", "foco": "core", "minutos": 10, "local": "bodyweight"\#(flag), "exercicios": [\#(mobility)] }] }"#)
    }

    @Test func mfitDayNeedsTheFlag() throws {
        let blocked = ClaudeStrengthValidator.validate(try response(replaces: nil), context: context())[0]
        #expect(blocked.errors == [.mfitDay])
        let allowed = ClaudeStrengthValidator.validate(try response(replaces: true), context: context())[0]
        #expect(allowed.errors.isEmpty)
        #expect(allowed.replacesMFIT)
        #expect(allowed.warnings.contains(.replacesMFIT))
        #expect(allowed.workout?.place == .bodyweight)
    }
}
