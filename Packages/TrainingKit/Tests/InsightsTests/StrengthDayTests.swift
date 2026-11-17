import Foundation
import Testing
@testable import Insights

@Suite struct StrengthDayTests {
    private static let mfitId = UUID(uuidString: "00000000-0000-4000-8000-0000000004d2")!

    @Test func oldSessionDecodesWithDefaults() throws {
        let json = #"{"id":"6F1B1E2A-1111-4222-8333-444455556666","weekday":2,"group":"core","legLoad":"light","name":"Core"}"#
        let session = try JSONDecoder().decode(TrainerStrengthSession.self, from: Data(json.utf8))
        #expect(session.source == .trainer)
        #expect(session.intensity == .moderate)
        #expect(session.minutes == TrainerStrengthSession.defaultMinutes)
        #expect(session.place == .gym)
    }

    @Test func oldMFITSessionDecodesAsMFIT() throws {
        let json = #"{"id":"\#(Self.mfitId.uuidString)","weekday":1,"group":"upper","legLoad":"light","name":"Superiores"}"#
        let session = try JSONDecoder().decode(TrainerStrengthSession.self, from: Data(json.utf8))
        #expect(session.source == .mfit)
    }

    @Test func roundTripKeepsNewFields() throws {
        let session = TrainerStrengthSession(weekday: 4, group: .core, legLoad: .light, name: "Mobilidade", source: .trainer, intensity: .light, minutes: 25, place: .home)
        let decoded = try JSONDecoder().decode(TrainerStrengthSession.self, from: JSONEncoder().encode(session))
        #expect(decoded == session)
    }

    @Test func mfitSyncKeepsTrainerDays() {
        let trainer = TrainerStrengthSession(weekday: 2, group: .core, legLoad: .light, name: "Mobilidade", source: .trainer)
        let oldMFIT = TrainerStrengthSession(id: Self.mfitId, weekday: 1, group: .upper, legLoad: .light, name: "Antigo", source: .mfit)
        let newMFIT = TrainerStrengthSession(weekday: 3, group: .lower, legLoad: .heavy, name: "MMII", source: .mfit)
        let merged = StrengthSessions.merge(mfit: [newMFIT], into: [trainer, oldMFIT])
        #expect(merged.map(\.name) == ["Mobilidade", "MMII"])
    }

    @Test func mfitComparisonIgnoresTrainerDays() {
        let trainer = TrainerStrengthSession(weekday: 2, group: .core, legLoad: .light, name: "Mobilidade", source: .trainer)
        let mfit = TrainerStrengthSession(weekday: 3, group: .lower, legLoad: .heavy, name: "MMII", source: .mfit)
        #expect(StrengthSessions.sameMFIT([mfit], [trainer, mfit]))
    }

    @Test func legLoadFollowsFocusAndIntensity() {
        #expect(StrengthSessions.legLoad(group: .lower, intensity: .moderate) == .heavy)
        #expect(StrengthSessions.legLoad(group: .lower, intensity: .light) == .light)
        #expect(StrengthSessions.legLoad(group: .fullBody, intensity: .heavy) == .heavy)
        #expect(StrengthSessions.legLoad(group: .upper, intensity: .heavy) == .light)
    }

    private static let week: [Int: TrainerDayKind] = [1: .easy, 2: .threshold, 3: .easy, 4: .off, 5: .easy, 6: .long, 7: .off]

    @Test func suggestionWithMFITComplementsWithMobilityAndCore() {
        let mfit = [1, 3, 5].map { TrainerStrengthSession(weekday: $0, group: .fullBody, legLoad: .heavy, name: "MFIT", source: .mfit) }
        let trainer = [2, 4].map { TrainerStrengthSession(weekday: $0, group: .lower, legLoad: .heavy, name: "x", source: .trainer) }
        let suggested = StrengthSuggestion.suggest(mfit + trainer, structure: Self.week)
        let days = suggested.filter { $0.source == .trainer }
        #expect(days.allSatisfy { $0.group == .core && $0.intensity == .light && $0.legLoad == .light })
        #expect(suggested.filter { $0.source == .mfit } == mfit)
    }

    @Test func suggestionKeepsHeavyLegsAwayFromQuality() {
        let trainer = [1, 3, 5].map { TrainerStrengthSession(weekday: $0, group: .core, legLoad: .light, name: "x", source: .trainer) }
        let suggested = StrengthSuggestion.suggest(trainer, structure: Self.week)
        let byDay = Dictionary(uniqueKeysWithValues: suggested.map { ($0.weekday, $0) })
        #expect(byDay[1]?.group == .core)
        #expect(byDay[3]?.group == .lower && byDay[3]?.intensity == .heavy)
        #expect(byDay[5]?.group == .core)
        for session in suggested where session.legLoad == .heavy {
            let next = [1, 2].map { (session.weekday + $0 - 1) % 7 + 1 }
            #expect(!next.contains { [.threshold, .vo2max, .long, .race].contains(Self.week[$0]) })
        }
    }
}
