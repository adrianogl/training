import Foundation
import WorkoutAnalysis

enum StravaSummaryBuilder {
    private typealias C = StravaConstants

    static func text(_ input: StravaSummaryInput) -> String? {
        guard let headline = headline(input) else { return nil }
        return [headline, highlight(input), C.signature].compactMap { $0 }.joined(separator: "\n")
    }

    static func title(_ input: StravaSummaryInput) -> String {
        input.goalPace ? C.goalPaceTitle : C.kindTitles[input.kind] ?? ""
    }

    private static func isQuality(_ input: StravaSummaryInput) -> Bool {
        (input.kind.isQuality || input.goalPace) && !input.steps.isEmpty && input.workPace != nil
    }

    private static func headline(_ input: StravaSummaryInput) -> String? {
        let body: String
        if isQuality(input), let pace = input.workPace {
            body = String(format: C.blocksFormat, structure(input.steps), WorkoutFormat.clock(pace))
        } else if let pace = input.paceSeconds, input.kilometers > 0 {
            body = String(format: C.volumeFormat, kilometers(input.kilometers), WorkoutFormat.clock(pace))
        } else {
            return nil
        }
        let scored = input.score.map { String(format: C.scoreFormat, body, $0) } ?? body
        return String(format: C.headlineFormat, title(input), scored)
    }

    static func structure(_ steps: [StravaBlockStep]) -> String {
        var groups: [(count: Int, size: String)] = []
        var lastSet: Int?
        for step in steps {
            if step.set == lastSet, let last = groups.indices.last {
                groups[last].count += 1
            } else {
                groups.append((1, step.size))
            }
            lastSet = step.set
        }
        let sizes = Set(groups.map(\.size))
        if sizes.count == 1, let size = sizes.first {
            let counts = groups.map(\.count)
            let total = counts.reduce(0, +)
            if groups.count == 1 || counts.allSatisfy({ $0 == 1 }) {
                return total == 1 ? size : String(format: C.blockFormat, total, size)
            }
            return String(format: C.setsSharedSizeFormat, counts.map(String.init).joined(separator: C.setSeparator), size)
        }
        return groups.map { $0.count == 1 ? $0.size : String(format: C.blockFormat, $0.count, $0.size) }.joined(separator: C.blockSeparator)
    }

    private static func highlight(_ input: StravaSummaryInput) -> String? {
        guard input.kind != .race || input.goalPace else { return nil }
        return bestPace(input) ?? longest(input) ?? lowerHeartRate(input) ?? fade(input)
    }

    private static func bestPace(_ input: StravaSummaryInput) -> String? {
        guard isQuality(input), let pace = input.workPace,
              let name = input.goalPace ? C.goalPaceName : C.highlightNames[input.kind],
              let best = input.similar.compactMap({ item in item.workPace.map { (item, $0) } }).min(by: { $0.1 < $1.1 })
        else { return nil }
        let delta = Int((best.1 - pace).rounded())
        guard Double(delta) >= C.paceBeatSeconds else { return nil }
        return String(format: C.paceBestFormat, name, delta, best.0.dateText)
    }

    private static func longest(_ input: StravaSummaryInput) -> String? {
        guard input.kind == .long, !input.goalPace,
              let previous = input.similar.max(by: { $0.kilometers < $1.kilometers }),
              input.kilometers - previous.kilometers >= C.longerBeatKm
        else { return nil }
        return String(format: C.longestFormat, kilometers(input.kilometers), kilometers(input.kilometers - previous.kilometers), previous.dateText)
    }

    private static func lowerHeartRate(_ input: StravaSummaryInput) -> String? {
        guard input.kind != .race, let pace = input.paceSeconds, let heartRate = input.heartRate else { return nil }
        let reference = input.similar.first { item in
            guard let itemPace = item.paceSeconds, let itemHeartRate = item.heartRate else { return false }
            return abs(itemPace - pace) <= C.paceSameSeconds && itemHeartRate - heartRate >= C.heartRateLowerDelta
        }
        guard let reference, let referenceHeartRate = reference.heartRate else { return nil }
        return String(format: C.heartRateFormat, Int((referenceHeartRate - heartRate).rounded()), reference.dateText)
    }

    private static func fade(_ input: StravaSummaryInput) -> String? {
        guard input.kind == .long, let km = input.fadeKm else { return nil }
        return String(format: C.fadeFormat, km)
    }

    private static func kilometers(_ value: Double) -> String {
        WorkoutFormat.kilometers(value * 1_000)
    }
}
