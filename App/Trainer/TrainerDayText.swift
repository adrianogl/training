import Insights
import TrainingCore

extension TrainerText {
    static let optionalTag = "opcional"
    static let racePaceName = "Ritmo de prova"
    static let mediumLongName = "Média-longa"
    static let fartlekName = "Fartlek"
    static let blockSeparator = " + "

    static func dayLine(_ workout: TrainerWorkout, strength: [TrainerStrengthLine] = [], longStage: Int? = nil) -> TrainerDayLine {
        guard workout.kind != .off else { return TrainerDayLine(title: restTitle, detail: "", tags: tags(workout, strength: strength, stage: nil)) }
        let pauses = TrainerEngine.plannedPauses(of: workout) > 0
        return TrainerDayLine(
            title: "\(dayName(workout)) · \(distance(workout.totalMeters))",
            detail: dayDetail(workout, pauses: pauses),
            tags: tags(workout, strength: strength, stage: pauses ? longStage : nil)
        )
    }

    static func dayName(_ workout: TrainerWorkout) -> String {
        switch workout.kind {
        case .easy where workout.variant == .mediumLong: mediumLongName
        case .optionalEasy where workout.variant == .fartlek: fartlekName
        case .optionalEasy, .easy: kindName(.easy)
        case .threshold where workout.method == .racePace: racePaceName
        case .vo2max where workout.method == .goalPace: goalPaceLabel
        default: kindName(workout.kind)
        }
    }

    private static func barePace(low: Double?, high: Double?) -> String? {
        paceRange(low: low, high: high)?.replacingOccurrences(of: "/km", with: "")
    }

    private static func dayDetail(_ workout: TrainerWorkout, pauses: Bool) -> String {
        let main = workout.steps.filter { $0.kind == .work && $0.method != .repetition }
        if pauses {
            let blocks = pauseBlocks(workout).map { $0.count > 1 ? "\(blockCount($0.count)) \(distance($0.meters))" : distance($0.meters) }.joined(separator: blockSeparator)
            let steady = workout.steps.filter { $0.kind == .steady }
            let pace = barePace(low: steady.compactMap(\.paceLow).min(), high: steady.compactMap(\.paceHigh).max())
            return pace.map { "\(blocks) a \($0)" } ?? blocks
        }
        if (workout.kind == .threshold || workout.kind == .vo2max), !main.isEmpty {
            let blocks = groupedBlocks(main).map { "\(blockCount($0.count)) \(distance($0.meters))" }.joined(separator: blockSeparator)
            return barePace(low: workout.paceLow, high: workout.paceHigh).map { "\(blocks) a \($0)" } ?? blocks
        }
        return paceRange(low: workout.paceLow, high: workout.paceHigh) ?? ""
    }

    private static func groupedBlocks(_ steps: [TrainerStep]) -> [(count: Int, meters: Double)] {
        var groups: [(count: Int, meters: Double)] = []
        for step in steps {
            if let last = groups.last, last.meters == step.meters {
                groups[groups.count - 1].count += step.repeats
            } else {
                groups.append((step.repeats, step.meters))
            }
        }
        return groups
    }

    private static func blockCount(_ count: Int) -> String {
        "\(count) ×"
    }

    private static func pauseBlocks(_ workout: TrainerWorkout) -> [(count: Int, meters: Double)] {
        var sizes: [Double] = []
        var current = 0.0
        for step in workout.steps {
            if step.kind == .recovery, step.restSeconds != nil {
                sizes.append(current)
                current = 0
            } else {
                current += step.meters * Double(step.repeats)
            }
        }
        sizes.append(current)
        var groups: [(count: Int, meters: Double)] = []
        for size in sizes {
            if let last = groups.last, last.meters == size {
                groups[groups.count - 1].count += 1
            } else {
                groups.append((1, size))
            }
        }
        return groups
    }

    private static func tags(_ workout: TrainerWorkout, strength: [TrainerStrengthLine], stage: Int?) -> [TrainerDayTag] {
        var result: [TrainerDayTag] = []
        if workout.kind == .optionalEasy { result.append(TrainerDayTag(text: optionalTag, style: .plain)) }
        if let closing = workout.steps.first(where: { $0.method == .repetition }) {
            result.append(TrainerDayTag(text: "+ \(closing.repeats) × \(distance(closing.meters))", style: .plain))
        }
        if let stage { result.append(TrainerDayTag(text: "etapa \(stage) de \(TrainerEngine.longStageCount)", style: .plain)) }
        if workout.edited, workout.kind != .off { result.append(TrainerDayTag(text: editedStatus, style: .plain)) }
        result.append(contentsOf: strength.map { TrainerDayTag(text: strengthTag($0), style: .strength) })
        return result
    }
}
