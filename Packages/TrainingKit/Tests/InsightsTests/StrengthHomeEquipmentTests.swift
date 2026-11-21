import Foundation
import Testing
import TrainingCore
@testable import Insights

@Suite struct StrengthHomeEquipmentTests {
    private func exercise(_ id: String) throws -> CatalogExercise {
        try #require(StrengthCatalog.exercise(id))
    }

    @Test func defaultHomeKeepsDumbbellsBandAndBodyweight() throws {
        #expect(try exercise("CORE/KETTLEBELL_WINDMILL").fits(.home) == false)
        #expect(try exercise("CORE/KETTLEBELL_WINDMILL").fits(.home, home: nil) == false)
        #expect(StrengthCatalogConstants.defaultHomeEquipment == [.dumbbell, .band])
    }

    @Test func chosenHomeEquipmentDecidesWhatFits() throws {
        let kettlebell = try exercise("CORE/KETTLEBELL_WINDMILL")
        let ball = try exercise("CORE/SWISS_BALL_JACKKNIFE")
        #expect(kettlebell.fits(.home, home: [.kettlebell]))
        #expect(!ball.fits(.home, home: [.kettlebell]))
        #expect(ball.fits(.home, home: [.swissBall]))
        let bodyweight = try #require(StrengthCatalog.all.first { $0.equipment == .bodyweight })
        #expect(bodyweight.fits(.home, home: []))
        #expect(kettlebell.fits(.gym, home: []))
    }

    @Test func generatorUsesOnlyTheHomeEquipment() {
        let session = TrainerStrengthSession(weekday: 2, group: .fullBody, legLoad: .light, name: "x", source: .trainer, intensity: .moderate, minutes: 40, place: .home)
        let workout = StrengthGenerator.workout(for: session, context: StrengthContext(homeEquipment: [.kettlebell]))
        let equipment = Set(workout.exercises.compactMap { StrengthCatalog.exercise($0.exerciseId)?.equipment })
        #expect(!workout.exercises.isEmpty)
        #expect(equipment.isSubset(of: [.kettlebell, .bodyweight]))
        #expect(equipment.contains(.kettlebell))
    }
}
