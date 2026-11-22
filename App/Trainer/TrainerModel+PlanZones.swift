import Foundation
import Insights
import TrainingCore

extension TrainerModel {
    var planZones: PlanZones {
        let key = PlanZonesKey(day: currentDay, paces: plan?.paces)
        if let cached = planZonesCache, cached.key == key { return cached.value }
        let value = PlanZones(paces: plan?.paces, bands: zoneBands)
        planZonesCache = (key, value)
        return value
    }
}

struct PlanZonesKey: Equatable {
    let day: Day
    let paces: TrainerPaces?
}
