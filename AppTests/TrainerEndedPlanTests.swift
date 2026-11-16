import Foundation
import Insights
import Storage
import Testing
import TrainingCore
@testable import trAIning

private final class EndedClock: @unchecked Sendable {
    var day: Day

    init(_ day: Day) {
        self.day = day
    }
}

@MainActor
@Suite struct TrainerEndedPlanTests {
    private static let monday = Day(iso: "2026-11-16")!

    private static let halfMarathon = TrainerTarget(
        kind: .race, name: "Meia de Floripa", date: monday.adding(days: 16 * TrainerConstants.weekdayCount), distanceMeters: 21_097.5, goalSeconds: 5_940
    )

    private static func makeModel(clock: EndedClock) throws -> TrainerModel {
        TrainerModel(
            container: try TrainingSchema.container(inMemory: true),
            store: TrainerStore(
                url: FileManager.default.temporaryDirectory.appending(path: "trainer-ended-\(UUID().uuidString).json"),
                defaults: UserDefaults(suiteName: "trainer-ended-\(UUID().uuidString)")!
            ),
            today: { clock.day }
        )
    }

    private static func createHalf(_ model: TrainerModel) async {
        await model.createPlan(
            target: halfMarathon, structure: TrainerEngine.defaultStructure, strength: [], startMeters: 60_000, peakMeters: 80_000
        )
    }

    @Test func activePlanKeepsAllWorkouts() async throws {
        let model = try Self.makeModel(clock: EndedClock(Self.monday))
        await Self.createHalf(model)
        #expect(model.hasActivePlan)
        #expect(model.activeWorkouts == model.plan?.workouts)
    }

    @Test func endedPlanDropsWorkoutsAfterTheEndDay() async throws {
        let clock = EndedClock(Self.monday.adding(days: 3 * TrainerConstants.weekdayCount))
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        await model.endCycle()
        let all = try #require(model.plan?.workouts)
        #expect(all.contains { $0.day > clock.day })
        #expect(!model.activeWorkouts.isEmpty)
        #expect(model.activeWorkouts.allSatisfy { $0.day <= clock.day })
    }

    @Test func endedPlanHasNoTrainerCardState() async throws {
        let model = try Self.makeModel(clock: EndedClock(Self.monday.adding(days: 3 * TrainerConstants.weekdayCount)))
        await Self.createHalf(model)
        await model.endCycle()
        #expect(!model.hasActivePlan)
    }

    @Test func passedRaceDropsWorkoutsAfterTheRace() async throws {
        let clock = EndedClock(Self.monday)
        let model = try Self.makeModel(clock: clock)
        await Self.createHalf(model)
        clock.day = Self.monday.adding(days: 20 * TrainerConstants.weekdayCount)
        let race = try #require(Self.halfMarathon.date)
        #expect(model.activeWorkouts.allSatisfy { $0.day <= race })
    }
}
