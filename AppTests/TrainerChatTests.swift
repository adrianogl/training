import Foundation
import Insights
import Testing
import TrainingCore
@testable import trAIning

@Suite struct TrainerChatTests {
    private static let today = Day(year: 2026, month: 11, day: 16)

    private static func workout(_ offset: Int, kind: TrainerDayKind = .easy, title: String = "Leve", steps: [TrainerStep] = []) -> TrainerWorkout {
        TrainerWorkout(day: today.adding(days: offset), kind: kind, title: title, totalMeters: 8_000, steps: steps, paceLow: 330, paceHigh: 345, rationale: "Recuperar entre os treinos fortes.")
    }

    private static func plan(workouts: [TrainerWorkout]) -> TrainerPlan {
        TrainerPlan(
            target: TrainerTarget(kind: .race, name: "Maratona", date: today.adding(days: 70), distanceMeters: 42_195, goalSeconds: 12_600),
            structure: [:],
            paces: TrainerPaces(easy: 340, long: 335, threshold: 290, vo2max: 265, thresholdSource: .work, vo2Source: .prediction),
            weeks: [TrainerWeek(index: 3, start: today, phase: .build, isRecovery: false, plannedMeters: 50_000, longMeters: 20_000, thresholdFocus: "", vo2Focus: "")],
            workouts: workouts,
            versions: [TrainerVersion(number: 2, createdAt: .now, trigger: .strengthChanged, summary: "Força passou para terça.", changes: [])],
            strength: [TrainerStrengthSession(weekday: 2, group: .lower, legLoad: .heavy, name: "Inferiores")],
            longMode: .blocks
        )
    }

    private static let weekPlan = plan(workouts: (0..<7).map { workout($0, kind: $0 == 5 ? .long : .easy, title: $0 == 5 ? "Longão" : "Leve") })

    @Test func contextHasGoalWeekPacesStrengthRulesAndChanges() {
        let context = TrainerChatContextBuilder.context(plan: Self.weekPlan, history: TrainerHistory(runs: []), today: Self.today)

        #expect(context.facts.contains("Meta: Maratona"))
        #expect(context.facts.contains("Semana atual: 3 de 1, fase construção, 50 km planejados, longão de 20 km"))
        #expect(context.facts.contains("limiar 4:50/km (dos seus treinos de qualidade)"))
        #expect(context.facts.contains("VO2 4:25/km (da previsão da Garmin)"))
        #expect(context.facts.contains("Força: Ter Inferiores"))
        #expect(context.facts.contains("Longão em blocos"))
        #expect(context.facts.contains("Toda prescrição é por distância"))
        #expect(context.dayLine?.contains("v2 (treinos de força atualizados): Força passou para terça.") == true)
        #expect(context.blockLines.count == 7)
    }

    @Test func contextListsOnlyNextSevenDays() {
        let plan = Self.plan(workouts: (0..<10).map { Self.workout($0) })
        let context = TrainerChatContextBuilder.context(plan: plan, history: TrainerHistory(runs: []), today: Self.today)

        #expect(context.blockLines.count == 7)
    }

    @Test func contextKeepsLastFiveRunsNewestFirst() {
        let runs = (1...7).map { TrainerRun(activityId: Int64($0), day: Self.today.adding(days: -$0), meters: 10_000, seconds: 3_000, kind: .easy, averageHeartRate: 140) }
        let context = TrainerChatContextBuilder.context(plan: Self.weekPlan, history: TrainerHistory(runs: runs), today: Self.today)

        #expect(context.similarLines.count == 5)
        #expect(context.similarLines[0].hasPrefix("15 nov: 10 km, leve, 5:00/km, FC média 140 bpm"))
    }

    @Test func contextWithoutRunsSaysSo() {
        let context = TrainerChatContextBuilder.context(plan: Self.weekPlan, history: TrainerHistory(runs: []), today: Self.today)

        #expect(context.similarLines == [TrainerChatConstants.runsEmpty])
    }

    @Test func detectsSwapOfTwoWeekdays() {
        let actions = TrainerChatActions.detect(question: "Posso trocar sábado e domingo?", answer: "", plan: Self.weekPlan, today: Self.today)

        let swap = TrainerChatSwap(first: Self.today.adding(days: 5), second: Self.today.adding(days: 6))
        #expect(actions == [.swap(swap)])
        #expect(TrainerChatActions.label(for: swap) == "Trocar sábado e domingo")
    }

    @Test func ignoresSwapWithoutVerbOrSecondDay() {
        #expect(TrainerChatActions.detect(question: "O que tem no sábado e no domingo?", answer: "", plan: Self.weekPlan, today: Self.today).isEmpty)
        #expect(TrainerChatActions.detect(question: "Posso trocar o sábado?", answer: "", plan: Self.weekPlan, today: Self.today).isEmpty)
    }

    @Test func ignoresSwapWhenADayIsOutsideThePlan() {
        let plan = Self.plan(workouts: (0..<5).map { Self.workout($0) })

        #expect(TrainerChatActions.detect(question: "Trocar sábado e domingo", answer: "", plan: plan, today: Self.today).isEmpty)
    }

    @Test func detectsRequestFromTravelPainAndFatigue() {
        func category(_ question: String, answer: String = "") -> TrainerRequestCategory? {
            let actions = TrainerChatActions.detect(question: question, answer: answer, plan: Self.weekPlan, today: Self.today)
            guard case .request(let prefill)? = actions.first else { return nil }
            return prefill.category
        }

        #expect(category("Vou viajar na quinta, o que muda?") == .travel)
        #expect(category("Estou com dor no joelho") == .pain)
        #expect(category("Ando com muito cansaço") == .fatigue)
        #expect(category("Por que o limiar está assim?") == nil)
        #expect(category("Como está meu treino?", answer: "Se sentir dor, peça uma readequação.") == .pain)
    }

    @Test func requestPrefillKeepsTheQuestionText() {
        let actions = TrainerChatActions.detect(question: "  Vou viajar semana que vem  ", answer: "", plan: Self.weekPlan, today: Self.today)

        #expect(actions == [.request(TrainerRequestPrefill(category: .travel, text: "Vou viajar semana que vem"))])
    }
}
