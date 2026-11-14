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

        let report = WeeklyReportBuilder.report(start: Day(iso: "2026-11-09")!, isCurrent: false, runs: runs, plannedKm: 50, race: ("LIVE!21K", 8))

        #expect(report.headline == "42 de 50 km planejados")
        #expect(report.text == "Faltaram 8 km do plano. Melhor treino: Intervalado (nota 84). LIVE!21K em 8 dias.")
        #expect(report.adherence == 0.84)
    }
}
