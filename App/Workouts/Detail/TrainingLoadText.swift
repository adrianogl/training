import Foundation

enum TrainingLoadText {
    private typealias C = TrainingLoadConstants

    static func caption(load: Double?, others: [Double]) -> String {
        guard let load, others.count >= C.minimumRuns else { return C.plain }
        let below = Double(others.filter { $0 < load }.count) / Double(others.count)
        return C.levels.first { below < $0.upTo }?.text ?? C.plain
    }
}
