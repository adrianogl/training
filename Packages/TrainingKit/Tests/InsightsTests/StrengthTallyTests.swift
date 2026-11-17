import Testing
import TrainingCore
@testable import Insights

@Suite struct StrengthTallyTests {
    @Test func countsDoneAndPlannedPerSource() {
        let monday = Day(iso: "2026-11-16")!
        let sessions = [
            TrainerStrengthSession(weekday: 1, group: .upper, legLoad: .light, name: "Sup", source: .mfit),
            TrainerStrengthSession(weekday: 2, group: .core, legLoad: .light, name: "Mob", source: .trainer),
            TrainerStrengthSession(weekday: 3, group: .lower, legLoad: .heavy, name: "MMII", source: .mfit),
            TrainerStrengthSession(weekday: 4, group: .core, legLoad: .light, name: "Mob", source: .trainer),
        ]
        let done: Set<Day> = [monday, monday.adding(days: 1), monday.adding(days: 2)]
        let tally = StrengthTally.week(start: monday, sessions: sessions, doneDays: done)
        #expect(tally == [
            StrengthSourceTally(source: .mfit, done: 2, planned: 2),
            StrengthSourceTally(source: .trainer, done: 1, planned: 2),
        ])
    }

    @Test func skipsSourcesWithoutSessions() {
        let monday = Day(iso: "2026-11-16")!
        let sessions = [TrainerStrengthSession(weekday: 2, group: .core, legLoad: .light, name: "Mob", source: .trainer)]
        #expect(StrengthTally.week(start: monday, sessions: sessions, doneDays: []) == [StrengthSourceTally(source: .trainer, done: 0, planned: 1)])
    }
}
