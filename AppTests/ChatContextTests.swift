import Foundation
import Insights
import Storage
import Testing
import TrainingCore
@testable import trAIning

@MainActor @Suite struct ChatContextTests {
    private static let info = RaceInfo(
        id: UUID(uuidString: "6B1F2C3D-4E5F-4061-8273-94A5B6C7D8E9")!, name: "Meia de BH", day: Day(iso: "2026-11-08")!,
        distance: 21_097.5, goalSeconds: 5_700, priority: .a, city: "Belo Horizonte", startTime: "6h"
    )

    @Test func raceKeyIsStablePerRace() {
        #expect(RaceChatContextBuilder.key(Self.info.id) == RaceChatContextBuilder.key(UUID(uuidString: "6B1F2C3D-4E5F-4061-8273-94A5B6C7D8E9")!))
        #expect(RaceChatContextBuilder.key(Self.info.id) != RaceChatContextBuilder.key(UUID()))
    }

    @Test func completedRaceContextCarriesResultSplitsAndLesson() {
        let summary = CompletedRaceSummary(
            info: Self.info, resultSeconds: 5_820, resultActivityId: 9, resultIsSuggestion: false, eveSeconds: 5_760, isPR: false,
            splits: [RaceSplit(index: 0, distance: 1_000, pace: 262, planned: 270), RaceSplit(index: 1, distance: 1_000, pace: 275, planned: nil)],
            lesson: AnalysisColumns(
                negative: [AnalysisItem(id: 0, text: "Ritmo caiu 12 s/km", evidence: "km 1–10: 4:30", why: "Largada forte.", blockOrdinal: nil)],
                positive: [], expected: []
            )
        )

        let context = RaceChatContextBuilder.completed(summary)

        #expect(context.copy.blocksName == "parciais_km_a_km")
        #expect(context.facts.contains("Resultado: 1:37:00."))
        #expect(context.blockLines == ["km 1: pace 4:22/km, planejado 4:30/km", "km 2: pace 4:35/km"])
        #expect(context.similarLines == ["Ajustar: Ritmo caiu 12 s/km (km 1–10: 4:30). Largada forte."])
        #expect(context.suggestions == WorkoutChatConstants.suggestionsCompletedRace)
    }

    @Test func nextRaceContextCarriesGoalStrategyAndBlock() {
        let context = RaceChatContextBuilder.next(
            info: Self.info, today: Day(iso: "2026-10-30")!,
            outlook: RaceOutlookFacts(today: 5_880, raceDay: 5_800, sentence: nil),
            checklist: [], blockReading: "", strategy: [], block: [], taper: nil, targetText: nil
        )

        #expect(context.facts.contains("Faltam 9 dias."))
        #expect(context.facts.contains("Previsão de hoje: 1:38:00."))
        #expect(context.dayLine == nil)
    }

    @Test func evolutionContextListsRecordsAndZones() {
        let context = EvolutionChatContextBuilder.context(
            verdictTitle: "Evoluindo", sentence: "", indicators: [], outlook: TodaySummary.empty.race, countdownDays: 9,
            cards: [], records: [PersonalRecord(label: "5 km", seconds: 1_230, date: Date(timeIntervalSince1970: 1_790_000_000), source: "Garmin")],
            zoneWeeks: [ZoneWeek(start: Day(iso: "2026-11-02")!, seconds: [600, 3_000, 1_200, 300, 0])]
        )

        #expect(context.facts.contains("Prova em 9 dias."))
        #expect(context.similarLines.first?.hasPrefix("5 km: 20:30 em ") == true)
        #expect(context.dayLine == "semana de 2/11: Z1 10 min, Z2 50 min, Z3 20 min, Z4 5 min, Z5 0 min")
    }
}
