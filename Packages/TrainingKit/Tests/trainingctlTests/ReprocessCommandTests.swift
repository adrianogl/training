import Sync
import Testing
@testable import trainingctl

@Test func reprocessLinesPrintOnlyFiveSkippedFITs() {
    let skipped = (1...7).map { SkippedFIT(activityId: Int64($0), description: "erro \($0)") }
    let lines = ReprocessCommand.lines(SyncReport(skippedFITs: skipped))

    #expect(lines.contains("FIT pulados: 7"))
    #expect(lines.filter { $0.hasPrefix("  atividade") }.count == 5)
    #expect(lines.contains("  atividade 5: erro 5"))
    #expect(!lines.contains("  atividade 6: erro 6"))
}
