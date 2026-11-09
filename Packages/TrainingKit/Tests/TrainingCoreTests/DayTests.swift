import Foundation
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

@Test func handlesLeapYears() {
    #expect(Day(iso: "2028-02-29")?.iso == "2028-02-29")
    #expect(Day(iso: "2026-02-29") == nil)
    #expect(Day(iso: "2100-02-29") == nil)
    #expect(Day(iso: "2028-02-28")!.adding(days: 1).iso == "2028-02-29")
    #expect(Day(iso: "2028-01-01")!.days(until: Day(iso: "2029-01-01")!) == 366)
}

@Test func windowsWithSingleOrInvertedRange() {
    let day = Day(iso: "2026-05-10")!
    #expect(windows(from: day, to: day, maxDays: 28) == [day...day])
    #expect(windows(from: day, to: day.adding(days: -1), maxDays: 28).isEmpty)
    #expect(windows(from: day, to: day.adding(days: 5), maxDays: 0).isEmpty)
}

@Test func todayDependsOnTimeZone() {
    let instant = Date(timeIntervalSince1970: 1_794_272_400)
    #expect(Day.today(in: TimeZone(identifier: "UTC")!, now: instant).iso == "2026-11-10")
    #expect(Day.today(in: TimeZone(identifier: "America/Sao_Paulo")!, now: instant).iso == "2026-11-09")
    #expect(Day.today(in: TimeZone(identifier: "Asia/Tokyo")!, now: instant).iso == "2026-11-10")
}
