struct HourHeatComparison: Equatable {
    let best: Int
    let reference: Int
    let saved: Int
}

struct BestHourPace: Equatable {
    let hour: Int
    let seconds: Int
    let extra: Int
}

enum HourHeatTone {
    case mild
    case warm
    case hot
}
