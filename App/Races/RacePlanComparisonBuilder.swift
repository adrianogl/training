import Foundation
import GarminAPI
import WorkoutAnalysis

enum RacePlanComparisonBuilder {
    private typealias C = RacePlanConstants

    static func build(splits: [RaceSplit], plan: PaceProPlan?) -> RacePlanComparison? {
        let planned: [Double?] = plan.map { plan in
            let seconds = plan.kilometerSeconds
            return splits.map { seconds.indices.contains($0.index) ? seconds[$0.index] : nil }
        } ?? splits.map(\.planned)
        var cumulative = 0.0
        let waterKm = Set((plan?.water ?? []).map { max(Int(($0 / 1_000).rounded(.up)) - 1, 0) })
        let rows: [RacePlanRow] = zip(splits, planned).compactMap { split, pace in
            guard let pace, split.distance >= 500 else { return nil }
            let factor = split.distance / 1_000
            let row = (planned: pace * factor, done: split.pace * factor)
            cumulative += row.done - row.planned
            return RacePlanRow(index: split.index, planned: row.planned, done: row.done, cumulative: cumulative, hasWater: waterKm.contains(split.index))
        }
        guard !rows.isEmpty else { return nil }
        return RacePlanComparison(
            sourceName: plan?.summary.name,
            planSeconds: plan?.summary.goalSeconds,
            rows: rows,
            verdict: verdict(rows, isPacePro: plan != nil)
        )
    }

    static func verdict(_ rows: [RacePlanRow], isPacePro: Bool) -> String {
        let total = rows.last?.cumulative ?? 0
        let target = isPacePro ? C.ofPacePro : C.ofAppStrategy
        var parts: [String] = []
        if abs(total) <= C.evenTolerance {
            parts.append("Terminou no tempo \(target).")
        } else {
            parts.append("Terminou \(gapText(abs(total))) \(total > 0 ? "atrás" : "à frente") \(target).")
        }
        if let stretch = longestStretch(rows) {
            let first = rows[stretch.lowerBound].index + 1
            let last = rows[stretch.upperBound].index + 1
            parts.append(first == last ? "Perdeu tempo no km \(first)." : "Perdeu tempo entre o km \(first) e o \(last).")
            let water = rows[stretch].filter(\.hasWater).map { $0.index + 1 }
            if let sentence = waterSentence(water) { parts.append(sentence) }
        }
        if let final = rows.last, final.delta <= -C.finishTolerance {
            parts.append("No fim, o km \(final.index + 1) saiu em \(WorkoutFormat.clock(final.done)), à frente do plano.")
        }
        return parts.joined(separator: " ")
    }

    static func waterSentence(_ km: [Int]) -> String? {
        guard let last = km.last else { return nil }
        guard km.count > 1 else { return "O km \(last) teve água, então até \(Int(C.waterAllowance)) s vêm do copo." }
        let list = km.dropLast().map(String.init).joined(separator: ", ") + " e \(last)"
        return "Desses, os km \(list) tiveram água, então até \(Int(C.waterAllowance)) s em cada um vêm do copo."
    }

    static func gapText(_ seconds: Double) -> String {
        let rounded = Int(seconds.rounded())
        return rounded < 60 ? "\(rounded) s" : WorkoutFormat.clock(Double(rounded))
    }

    static func signedGap(_ seconds: Double) -> String {
        let rounded = Int(seconds.rounded())
        return (rounded > 0 ? "+" : rounded < 0 ? "−" : "±") + gapText(Double(abs(rounded)))
    }

    private static func longestStretch(_ rows: [RacePlanRow]) -> ClosedRange<Int>? {
        var best: ClosedRange<Int>?
        var start: Int?
        for (offset, row) in rows.enumerated() {
            if row.delta > C.strayTolerance + (row.hasWater ? C.waterAllowance : 0) || (row.hasWater && row.delta > C.strayTolerance && start != nil) {
                if start == nil { start = offset }
                let current = start!...offset
                if best.map({ current.count > $0.count }) ?? true { best = current }
            } else {
                start = nil
            }
        }
        return best.flatMap { $0.count >= 2 ? $0 : nil }
    }
}
