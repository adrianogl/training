import Testing
@testable import TrainingCore

@Test func parsesAndFormatsIso() {
    #expect(Day(iso: "2026-11-07")?.iso == "2026-11-07")
    #expect(Day(iso: "2026-13-01") == nil)
}

@Test func arithmeticCrossesMonths() {
    #expect(Day(year: 2026, month: 10, day: 30).adding(days: 3).iso == "2026-11-02")
    #expect(Day(iso: "2026-01-01")!.days(until: Day(iso: "2026-11-07")!) == 310)
}

@Test func weekStartsOnMonday() {
    #expect(Day(iso: "2026-11-07")!.weekStart.iso == "2026-11-02")
}

@Test func windowsRespectLimit() {
    let w = windows(from: Day(iso: "2026-01-01")!, to: Day(iso: "2026-03-15")!, maxDays: 28)
    #expect(w.count == 3)
    #expect(w.first!.lowerBound.iso == "2026-01-01" && w.first!.upperBound.iso == "2026-01-28")
    #expect(w.last!.upperBound.iso == "2026-03-15")
}
