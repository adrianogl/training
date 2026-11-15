import Foundation
import Testing
import TrainingCore
@testable import trAIning

@Suite struct WeeklyReportTests {
    @Test func reportWeekDependsOnWeekday() {
        #expect(WeeklyReportBuilder.reportWeek(today: Day(iso: "2026-11-15")!)?.isCurrent == true)
        #expect(WeeklyReportBuilder.reportWeek(today: Day(iso: "2026-11-16")!)?.start == Day(iso: "2026-11-09")!)
        #expect(WeeklyReportBuilder.reportWeek(today: Day(iso: "2026-11-13")!) == nil)
    }

    @Test func reportComparesWithPlanAndNamesBestRun() {
        let runs = [
            ReportRun(title: "Intervalado", kilometers: 12, score: 84),
            ReportRun(title: "Longão", kilometers: 20, score: 73),
            ReportRun(title: "Leve", kilometers: 10, score: nil),
        ]

        let report = WeeklyReportBuilder.report(start: Day(iso: "2026-11-09")!, isCurrent: false, runs: runs, plannedKm: 50, race: ReportRace(name: "LIVE!21K", days: 8))

        #expect(report.headline == "42 de 50 km planejados")
        #expect(report.text == "Faltaram 8 km do plano. Melhor treino: Intervalado (nota 84). LIVE!21K em 8 dias.")
        #expect(report.adherence == 0.84)
    }

    private static let start = Day(iso: "2026-11-09")!

    private static func session(_ offset: Int, _ kind: SessionKind, _ km: Double) -> PlannedSession {
        PlannedSession(day: start.adding(days: offset), title: "Treino", kilometers: km, kind: kind)
    }

    private static func run(_ offset: Int, _ kind: SessionKind, _ km: Double) -> ReportRun {
        ReportRun(title: "Corrida", kilometers: km, score: nil, day: start.adding(days: offset).iso, kind: kind)
    }

    @Test func cleanTitleDropsRepeatedWordAndDate() {
        #expect(WeeklyReportBuilder.cleanTitle("Corrida Corrida fácil seg 09/11") == "Corrida fácil")
        #expect(WeeklyReportBuilder.cleanTitle("Corrida Longo sáb 14/11") == "Corrida Longo")
        #expect(WeeklyReportBuilder.cleanTitle("Limiar 8 × 1 km") == "Limiar 8 × 1 km")
    }

    @Test func bestCardUsesCleanTitleDayAndPace() {
        let runs = [ReportRun(title: "Corrida Corrida fácil seg 09/11", kilometers: 12, score: 100, day: "2026-11-09", kind: .easy, paceSeconds: 290)]

        let report = WeeklyReportBuilder.report(start: Self.start, isCurrent: true, runs: runs, plannedKm: nil, race: nil)

        #expect(report.bestCard?.title == "Corrida fácil · seg 9")
        #expect(report.bestCard?.detail == "12,0 km a 4:50/km")
    }

    @Test func percentAndMissingKilometers() {
        let runs = [Self.run(0, .easy, 59.7)]

        let report = WeeklyReportBuilder.report(start: Self.start, isCurrent: true, runs: runs, plannedKm: 66.2, race: nil)

        #expect(report.percent == 90)
        #expect(abs((report.missingKm ?? 0) - 6.5) < 0.001)
        #expect(!report.isComplete)
    }

    @Test func completeOnlyWhenPlanReachedAndEveryPlannedDayDone() {
        let sessions = [Self.session(0, .easy, 10), Self.session(2, .easy, 10), Self.session(5, .long, 16)]
        let all = [Self.run(0, .easy, 10), Self.run(2, .easy, 10), Self.run(5, .long, 16)]
        let skipped = [Self.run(0, .easy, 14), Self.run(5, .long, 22)]
        let partialLong = [Self.run(0, .easy, 10), Self.run(2, .easy, 10), Self.run(5, .long, 12), Self.run(6, .easy, 6)]

        func report(_ runs: [ReportRun]) -> WeeklyReport {
            WeeklyReportBuilder.report(start: Self.start, isCurrent: false, runs: runs, plannedKm: 36, race: nil, sessions: sessions)
        }

        #expect(report(all).isComplete)
        #expect(report(all).text.hasPrefix("Semana completa."))
        #expect(!report(skipped).isComplete)
        #expect(report(skipped).days[2].state == .missed)
        #expect(!report(partialLong).isComplete)
        #expect(report(partialLong).days[5].state == .partial)
    }

    @Test func notesSayWhatWasMissedAndRaceFocus() {
        let sessions = [Self.session(0, .easy, 10), Self.session(4, .easy, 8), Self.session(5, .long, 16)]
        let runs = [Self.run(0, .easy, 10), Self.run(5, .long, 12.7)]
        let race = ReportRace(name: "LIVE!21K", days: 7, day: Self.start.adding(days: 13))

        let report = WeeklyReportBuilder.report(start: Self.start, isCurrent: true, runs: runs, plannedKm: 34, race: race, sessions: sessions, today: Self.start.adding(days: 6))

        #expect(report.note == "Faltou a rodagem de sexta e o longão parou no km 12,7. A semana que vem é de prova: mantenha as rodagens leves e chegue descansado no domingo.")
        #expect(report.quality == nil)
        #expect(report.long == ReportLong(doneKm: 12.7, plannedKm: 16))
        #expect(report.runCount == ReportCount(done: 2, planned: 3))
    }

    @Test func qualityCountsOnlyDaysDoneAsPlanned() {
        let sessions = [Self.session(1, .threshold, 13), Self.session(3, .intervals, 10)]
        let runs = [Self.run(1, .threshold, 13.1), Self.run(3, .intervals, 6)]

        let report = WeeklyReportBuilder.report(start: Self.start, isCurrent: false, runs: runs, plannedKm: nil, race: nil, sessions: sessions)

        #expect(report.quality == ReportCount(done: 1, planned: 2))
    }

    @Test func sessionKindComesFromTitleOrSteps() {
        #expect(SessionKind(title: "Longo 16 km", steps: []) == .long)
        #expect(SessionKind(title: "Limiar 8 × 1 km", steps: []) == .threshold)
        #expect(SessionKind(title: "VO2 5 × 1 km", steps: []) == .intervals)
        #expect(SessionKind(title: "Rodagem", steps: []) == .easy)
    }
}
