import Foundation

public enum RunTimeEstimate {
    static let metersPerKilometer = 1_000.0

    public static func total(_ parts: [RunTimePart], fallback: PaceBand?) -> RunTimeRange? {
        var range = RunTimeRange(fastest: 0, slowest: 0)
        for part in parts {
            switch part {
            case .fixed(let seconds):
                range.fastest += max(seconds, 0)
                range.slowest += max(seconds, 0)
            case .distance(let meters, let pace):
                guard meters > 0 else { continue }
                guard let band = pace ?? fallback else { return nil }
                if pace == nil { range.approximate = true }
                range.fastest += meters / metersPerKilometer * band.fastest
                range.slowest += meters / metersPerKilometer * band.slowest
            case .open:
                range.approximate = true
            }
        }
        return range.slowest > 0 ? range : nil
    }
}
