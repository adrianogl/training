import Foundation
import Insights
import TrainingCore

extension TrainerModel {
    var claudeBuildingPlan: StrengthPlan? {
        guard let strengthPlan, strengthPlan.builder == .claude, currentDay.adding(days: 1) <= strengthPlan.end else { return nil }
        return strengthPlan
    }

    func claudePeriod(_ period: ClaudeRequestPeriod, race: ClaudeRaceTarget?) -> (first: Day, last: Day) {
        if let plan = claudeBuildingPlan {
            return (max(plan.start, currentDay.adding(days: 1)), plan.end)
        }
        switch period {
        case .nextWeek:
            let first = currentDay.weekStart.adding(days: TrainerConstants.weekdayCount)
            return (first, first.adding(days: TrainerConstants.weekdayCount - 1))
        case .untilRace:
            let first = currentDay.adding(days: 1)
            let last = race.map { $0.day.adding(days: -1) } ?? first.adding(days: ClaudeConstants.fallbackWeeks * TrainerConstants.weekdayCount - 1)
            return (first, max(first, last))
        }
    }

    func claudeRuns(first: Day, last: Day) -> [Day: (kind: TrainerDayKind, name: String)] {
        var runs: [Day: (kind: TrainerDayKind, name: String)] = [:]
        if let plan {
            for workout in plan.workouts where workout.day >= first && workout.day <= last && workout.kind != .off {
                runs[workout.day] = (workout.kind, workout.title)
            }
        } else {
            for workout in externalWorkouts where workout.day >= first && workout.day <= last {
                runs[workout.day] = (ExternalDayKind.kind(workout), workout.name)
            }
        }
        return runs
    }

    func claudeContextInput(_ period: ClaudeRequestPeriod, race: ClaudeRaceTarget?) -> ClaudeContextInput {
        let (first, last) = claudePeriod(period, race: race)
        let cache = StrengthProgramStore().load()
        let mfitWeek = TrainerStrengthContextBuilder.coveredByWeekday(program: cache.program, schedule: StrengthSchedule(), week: first.weekStart)
        let readiness = Dictionary(uniqueKeysWithValues: (1...ClaudeConstants.readinessDays).compactMap { offset -> (Day, Int)? in
            let day = currentDay.adding(days: -offset + 1)
            return history.readiness[day].map { (day, $0) }
        })
        let prefs = TrainerStrengthPrefsStore().load()
        return ClaudeContextInput(
            today: currentDay, first: first, last: last, trainerSessions: strengthSessions, mfit: mfitWeek,
            runs: claudeRuns(first: first, last: last), readiness: readiness, pain: prefs.pain,
            loads: TrainerStrengthContextBuilder.loads(cache.loads).mapValues(\.weight), race: race,
            notes: ExerciseNotesStore().allActive(), planLocked: claudeBuildingPlan != nil, homeEquipment: prefs.effectiveHomeEquipment
        )
    }

    func claudeValidationContext(_ input: ClaudeContextInput) -> ClaudeValidationContext {
        ClaudeValidationContext(
            today: input.today, first: input.first, last: input.last, trainerSessions: input.trainerSessions,
            mfitWeekdays: claudeBuildingPlan == nil ? Set(strengthSessions.filter { $0.source == .mfit }.map(\.weekday)) : [],
            runKinds: input.runs.mapValues(\.kind), raceDay: input.race?.day, pain: input.pain, lastLoads: input.loads,
            homeEquipment: input.homeEquipment
        )
    }

    func isClaudeDay(_ day: Day) -> Bool {
        claudeWorkout(on: day) != nil
    }
}

extension TrainerModel {
    @discardableResult
    func publishClaudeContext(race: ClaudeRaceTarget?) -> Bool {
        let input = claudeContextInput(.untilRace, race: race)
        let envelope = ClaudeContextEnvelope(
            atualizado: ISO8601DateFormatter().string(from: .now),
            texto: ClaudeContextBuilder.text(input, extra: nil),
            contexto: ClaudeContextBuilder.payload(input)
        )
        return ClaudeMailbox().publish(envelope)
    }

    func claudeInboxResults(_ inbox: ClaudeInbox, race: ClaudeRaceTarget?) -> ClaudeImportState {
        claudeImportState(parsing: inbox.json, race: race)
    }

    func claudeImportState(parsing text: String, race: ClaudeRaceTarget?) -> ClaudeImportState {
        do {
            let response = try ClaudeStrengthParser.parse(text)
            var context = claudeValidationContext(claudeContextInput(.untilRace, race: race))
            let plan = claudeBuildingPlan
            if plan == nil { context.first = currentDay.adding(days: 1) }
            var results = ClaudeStrengthValidator.validate(response, context: context)
            if plan != nil {
                results = results.map { result in
                    var result = result
                    result.replacesMFIT = false
                    result.warnings.removeAll { $0 == .replacesMFIT }
                    return result
                }
            }
            return ClaudeImportState(summary: response.summary, results: results, failure: nil, planId: plan?.id)
        } catch ClaudeStrengthParseError.unsupportedVersion(let version) {
            return ClaudeImportState(summary: nil, results: [], failure: String(format: ClaudeText.unsupportedFormat, version))
        } catch {
            return ClaudeImportState(summary: nil, results: [], failure: ClaudeText.invalidJSON)
        }
    }

    func planNotice(for state: ClaudeImportState) -> String? {
        guard let plan = claudeBuildingPlan, plan.id == state.planId,
              state.results.contains(where: { $0.errors.contains(.outOfPeriod) || $0.errors.contains(.notTrainerDay) }) else { return nil }
        return ClaudeText.outsidePlanNotice(plan)
    }

    func applyClaudeImport(_ state: ClaudeImportState) {
        claudeStore.apply(state.results, summary: state.summary, planId: state.planId)
    }
}
