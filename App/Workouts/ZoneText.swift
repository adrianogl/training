import Foundation
import Insights

enum ZoneText {
    static func short(_ zone: Int) -> String {
        "Z\(zone)"
    }

    static func label(_ zone: Int, band: TrainerZoneBand?) -> String {
        guard let range = heartRate(band) else { return short(zone) }
        return "\(short(zone)) · \(range)"
    }

    static func heartRate(_ band: TrainerZoneBand?) -> String? {
        switch (band?.heartRateLow, band?.heartRateHigh) {
        case let (low?, high?): "\(low)–\(high)"
        case let (nil, high?): "< \(high + 1)"
        case let (low?, nil): "> \(low - 1)"
        default: nil
        }
    }
}
