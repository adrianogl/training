import Foundation
import GarminAPI
import Testing
import TrainingCore
@testable import trAIning

@Suite struct RaceNoticeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return calendar
    }

    private let plan = PaceProPlan(
        summary: PaceProSummary(id: 1, name: "Live! Run XP", distance: 10_005, goalSeconds: 2400, created: nil),
        splits: [237.259, 477.3, 717.543, 956.399, 1195.036, 1434.934, 1674.903, 1913.096, 2152.073, 2393.484]
            .enumerated().map { PaceProSplit(distance: Double($0.offset + 1) * 1_000, time: $0.element) }
    )

    private func time(_ date: Date) -> String {
        let parts = calendar.dateComponents([.day, .hour, .minute], from: date)
        return String(format: "%02d %02d:%02d", parts.day!, parts.hour!, parts.minute!)
    }

    @Test func schedulesEveAndMorningFromStartTime() throws {
        let notices = RaceNoticeBuilder.notices(id: UUID(), name: "LIVE!21K", day: Day(iso: "2026-11-22")!, startTime: "07:00", distance: 10_000, goalSeconds: 2400, plan: plan, calendar: calendar)
        try #require(notices.count == 2)
        #expect(time(notices[0].date) == "21 19:00")
        #expect(notices[0].title == "LIVE!21K amanhã, largada 07:00")
        #expect(notices[0].text == "Meta 40:00, 4:00/km. Para dormir 8 h e acordar às 05:00, deite até 21:00. Separe número, chip e tênis hoje.")
        #expect(time(notices[1].date) == "22 05:00")
        #expect(notices[1].text == "Largada 07:00. Pace Pro: 1º km em 3:57, depois 4:00/km até o fim. Coma até 05:30 e abra o app para ver a prontidão.")
    }

    @Test func longRaceRemindsGelAndUsesGoalPaceWithoutPlan() {
        let notices = RaceNoticeBuilder.notices(id: UUID(), name: "Meia", day: Day(iso: "2026-12-06")!, startTime: "06:30", distance: 21_097, goalSeconds: 5_400, plan: nil, calendar: calendar)
        #expect(notices[0].text.hasSuffix("Separe também o gel."))
        #expect(notices[1].text.contains("Ritmo da meta: 4:16/km."))
        #expect(time(notices[1].date) == "06 04:30")
    }
}

@Suite struct RacePlanComparisonTests {
    @Test func comparesEachKilometerWithPacePro() throws {
        let plan = PaceProPlan(
            summary: PaceProSummary(id: 1, name: "Live! Run XP", distance: 10_005, goalSeconds: 2400, created: nil),
            splits: (1...4).map { PaceProSplit(distance: Double($0) * 1_000, time: Double($0) * 240) }
        )
        let splits = [234.0, 246, 248, 230].enumerated().map { RaceSplit(index: $0.offset, distance: 1_000, pace: $0.element, planned: nil) }
        let comparison = try #require(RacePlanComparisonBuilder.build(splits: splits, plan: plan))
        #expect(comparison.rows.map(\.delta) == [-6, 6, 8, -10])
        #expect(comparison.rows.map(\.cumulative) == [-6, 0, 8, -2])
        #expect(comparison.sourceName == "Live! Run XP")
        #expect(comparison.verdict == "Terminou no tempo do Pace Pro. Perdeu tempo entre o km 2 e o 3. No fim, o km 4 saiu em 3:50, à frente do plano.")
    }

    @Test func fallsBackToAppStrategy() throws {
        let splits = [RaceSplit(index: 0, distance: 1_000, pace: 250, planned: 240), RaceSplit(index: 1, distance: 1_000, pace: 250, planned: 240)]
        let comparison = try #require(RacePlanComparisonBuilder.build(splits: splits, plan: nil))
        #expect(comparison.sourceName == nil)
        #expect(comparison.verdict == "Terminou 20 s atrás da estratégia do app. Perdeu tempo entre o km 1 e o 2.")
    }
}

@Suite struct RaceWaterTests {
    private let plan = PaceProPlan(
        summary: PaceProSummary(id: 1, name: "Live Run XP 2026", distance: 10_005, goalSeconds: 2400, created: nil, courseId: 530929657),
        splits: (1...10).map { PaceProSplit(distance: Double($0) * 1_000, time: Double($0) * 240) },
        water: [1_635.9, 3_232.8, 4_822.2, 5_191.6, 6_780.4, 8_391.4]
    )

    @Test func morningNoticeListsWaterPoints() {
        #expect(RaceNoticeBuilder.waterText(plan) == "Água no km 1,6, 3,2, 4,8, 5,2, 6,8 e 8,4. ")
        #expect(RaceNoticeBuilder.waterText(nil) == "")
    }

    @Test func analysisMarksWaterKilometersAndExplainsStretch() throws {
        let done = [237.0, 240, 243, 242, 244, 246, 244, 240, 238, 233]
        let splits = done.enumerated().map { RaceSplit(index: $0.offset, distance: 1_000, pace: $0.element, planned: nil) }
        let comparison = try #require(RacePlanComparisonBuilder.build(splits: splits, plan: plan))
        #expect(comparison.rows.filter(\.hasWater).map { $0.index + 1 } == [2, 4, 5, 6, 7, 9])
        #expect(comparison.verdict.contains("Perdeu tempo entre o km 3 e o 7."))
        #expect(comparison.verdict.contains("Desses, os km 4, 5, 6 e 7 tiveram água, então até 3 s em cada um vêm do copo."))
    }
}
