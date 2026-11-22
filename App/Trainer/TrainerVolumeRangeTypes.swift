import Insights

struct TrainerVolumeRangeRow: Identifiable, Equatable {
    let runs: Int
    let range: TrainerVolumeRange

    var id: Int { runs }
}
