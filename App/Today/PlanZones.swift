import GarminAPI
import Insights
import SwiftUI

struct PlanZones: Equatable {
    var paces: TrainerPaces?
    var bands: [TrainerZoneBand] = []

    func zone(_ step: PlannedStep) -> Int? {
        TrainerZones.zone(planned: step, paces: paces, bands: bands)
    }

    func band(_ zone: Int) -> TrainerZoneBand? {
        bands.first { $0.zone == zone }
    }
}

extension EnvironmentValues {
    @Entry var planZones: PlanZones?
}
