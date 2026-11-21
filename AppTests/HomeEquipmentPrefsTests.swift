import Foundation
import Insights
import Testing
@testable import trAIning

@Suite struct HomeEquipmentPrefsTests {
    private func store() -> TrainerStrengthPrefsStore {
        TrainerStrengthPrefsStore(defaults: UserDefaults(suiteName: "home-eq-" + UUID().uuidString)!)
    }

    @Test func startsWithDumbbellsAndBand() {
        #expect(store().load().effectiveHomeEquipment == [.dumbbell, .band])
    }

    @Test func togglingSavesTheChoice() {
        let prefs = store()
        prefs.toggleHomeEquipment(.kettlebell)
        #expect(prefs.load().effectiveHomeEquipment == [.dumbbell, .band, .kettlebell])
        prefs.toggleHomeEquipment(.dumbbell)
        #expect(prefs.load().effectiveHomeEquipment == [.band, .kettlebell])
        prefs.toggleHomeEquipment(.bodyweight)
        #expect(!prefs.load().effectiveHomeEquipment.contains(.bodyweight))
    }

    @Test func oldPrefsWithoutTheFieldStillDecode() throws {
        let old = #"{"pain":["knee"],"swaps":{},"keptOriginal":[]}"#
        let prefs = try JSONDecoder().decode(TrainerStrengthPrefs.self, from: Data(old.utf8))
        #expect(prefs.pain == [.knee])
        #expect(prefs.effectiveHomeEquipment == [.dumbbell, .band])
    }

    @Test func optionsAndNames() {
        #expect(StrengthCatalogConstants.homeEquipmentOptions.map(StrengthPlanText.equipmentName) == ["Halteres", "Elástico", "Kettlebell", "Bola de pilates", "Medicine ball", "Fita de suspensão", "Barra e anilhas"])
    }
}
