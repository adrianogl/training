import Foundation
import Insights

enum TrainerZoneGuideText {
    private typealias C = TrainerZoneGuideConstants

    static func pace(_ band: TrainerZoneBand) -> String {
        guard let low = band.paceLow, let high = band.paceHigh else { return band.zone == 1 ? C.trot : "—" }
        return TrainerText.paceRange(low: low, high: high)?.replacingOccurrences(of: "/km", with: "") ?? "—"
    }

    static func realLine(_ real: [Int: Double]) -> String? {
        let parts = real.keys.sorted().filter { $0 > 1 }.compactMap { zone in real[zone].map { "\(ZoneText.short(zone)) \(TrainerText.pace($0).replacingOccurrences(of: "/km", with: ""))" } }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func realNote(_ real: [Int: Double], bands: [TrainerZoneBand]) -> String? {
        for band in bands where band.zone > 1 {
            guard let actual = real[band.zone], let low = band.paceLow, let high = band.paceHigh else { continue }
            if actual > high + C.realTolerance { return String(format: C.slowerThanPlan, band.zone) }
            if actual < low - C.realTolerance { return String(format: C.fasterThanPlan, band.zone) }
        }
        return nil
    }
}
