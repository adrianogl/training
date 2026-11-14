import FITReader
import Foundation
import WorkoutAnalysis

struct BlockName: Equatable {
    let text: String
    let feminine: Bool
    let plural: Bool
}

enum BlockNaming {
    private typealias C = BlockNamingConstants

    static func name(_ positions: [Int], blocks: [WorkoutBlock]) -> BlockName? {
        let valid = positions.filter { blocks.indices.contains($0) }.sorted()
        guard let first = valid.first else { return nil }
        let kind = blocks[first].kind
        guard valid.allSatisfy({ blocks[$0].kind == kind }) else {
            return BlockName(text: valid.map { single($0, blocks: blocks).text }.joined(separator: ", "), feminine: false, plural: true)
        }
        switch kind {
        case .warmup: return BlockName(text: C.warmup, feminine: false, plural: false)
        case .cooldown: return BlockName(text: C.cooldown, feminine: false, plural: false)
        case .recovery: return recoveries(valid, blocks: blocks)
        case .active: return actives(valid, blocks: blocks)
        }
    }

    static func single(_ position: Int, blocks: [WorkoutBlock]) -> BlockName {
        name([position], blocks: blocks) ?? BlockName(text: blocks[position].label.lowercased(), feminine: false, plural: false)
    }

    static func tableLabel(_ block: WorkoutBlock) -> (title: String, detail: String?) {
        let detail = block.prescribed.flatMap { durationText($0.duration) }
        switch block.kind {
        case .warmup: return (C.tableWarmup, detail)
        case .cooldown: return (C.tableCooldown, detail)
        case .recovery: return (C.tableRecovery, detail ?? WorkoutListModel.clockText(block.seconds))
        case .active:
            guard isNumbered(block) else { return (block.label, detail) }
            let format = isRepeat(block) ? C.tableRepeatFormat : C.tableBlockFormat
            return (String(format: format, block.ordinal), detail)
        }
    }

    static func durationText(_ duration: StepDuration) -> String? {
        switch duration {
        case .distance(let meters):
            return meters < BlockNamingConstants.metersUpTo || meters.truncatingRemainder(dividingBy: WorkoutConstants.metersPerKilometer) != 0
                ? "\(Int(meters.rounded())) m"
                : "\(Int(meters / WorkoutConstants.metersPerKilometer)) km"
        case .time(let seconds):
            return seconds.truncatingRemainder(dividingBy: 60) == 0
                ? "\(Int(seconds / 60)) \(C.minuteUnit)"
                : seconds < 60 ? "\(Int(seconds)) \(C.secondUnit)" : WorkoutListModel.clockText(seconds)
        case .open, .repeatSteps:
            return nil
        }
    }

    static func sections(_ blocks: [WorkoutBlock]) -> [(title: String, positions: [Int])] {
        var sections: [(title: String, positions: [Int])] = []
        for position in blocks.indices {
            let title = sectionTitle(blocks[position].kind, blocks: blocks)
            if let last = sections.last, last.title == title {
                sections[sections.count - 1].positions.append(position)
            } else {
                sections.append((title, [position]))
            }
        }
        return sections
    }

    private static func sectionTitle(_ kind: BlockKind, blocks: [WorkoutBlock]) -> String {
        switch kind {
        case .warmup: return C.sectionWarmup
        case .cooldown: return C.sectionCooldown
        case .active, .recovery:
            let actives = blocks.filter { $0.kind == .active }
            let sizes = Set(actives.compactMap { $0.prescribed.flatMap { durationText($0.duration) } })
            guard actives.count > 1, actives.allSatisfy(isRepeat), sizes.count == 1, let size = sizes.first else { return C.sectionMain }
            return String(format: C.sectionSeriesFormat, actives.count, size)
        }
    }

    static func ordinal(_ value: Int) -> String {
        C.ordinals.indices.contains(value - 1) ? C.ordinals[value - 1] : "\(value)º"
    }

    private static func isRepeat(_ block: WorkoutBlock) -> Bool {
        block.label.hasPrefix(WorkoutDetailConstants.repeatLabelPrefix)
    }

    private static func isNumbered(_ block: WorkoutBlock) -> Bool {
        isRepeat(block) || block.label.hasPrefix(WorkoutDetailConstants.blockLabelPrefix)
    }

    private static func actives(_ positions: [Int], blocks: [WorkoutBlock]) -> BlockName {
        let chosen = positions.map { blocks[$0] }
        guard chosen.allSatisfy(isNumbered) else {
            return BlockName(text: chosen.map { $0.label.lowercased() }.joined(separator: ", "), feminine: false, plural: chosen.count > 1)
        }
        let repeats = chosen.allSatisfy(isRepeat)
        let pluralNoun = chosen.count > 1 && !isRun(chosen.map(\.ordinal))
        let noun = repeats ? (pluralNoun ? C.repeatPlural : C.repeatNoun) : (pluralNoun ? C.blockPlural : C.blockNoun)
        let sizes = Set(chosen.compactMap { $0.prescribed.flatMap { durationText($0.duration) } })
        let size = sizes.count == 1 ? sizes.first.map { " \(C.of) \($0)" } ?? "" : ""
        return BlockName(text: "\(sequence(chosen.map(\.ordinal), article: nil)) \(noun)\(size)", feminine: false, plural: chosen.count > 1)
    }

    private static func recoveries(_ positions: [Int], blocks: [WorkoutBlock]) -> BlockName {
        let previous = positions.compactMap { position in
            blocks[..<position].last { $0.kind == .active && isNumbered($0) }
        }
        let plural = positions.count > 1
        let noun = plural ? C.recoveryPlural : C.recoverySingular
        guard previous.count == positions.count, let first = previous.first else {
            return BlockName(text: noun, feminine: true, plural: plural)
        }
        let activeNoun = isRepeat(first) ? C.repeatNoun : C.blockNoun
        let ordinals = previous.map(\.ordinal)
        if isRun(ordinals) {
            return BlockName(text: "\(noun) \(C.from) \(ordinal(ordinals[0])) \(C.to) \(ordinal(ordinals[ordinals.count - 1])) \(activeNoun)", feminine: true, plural: true)
        }
        return BlockName(text: "\(noun) \(C.after) \(sequence(ordinals, article: C.from)) \(activeNoun)", feminine: true, plural: plural)
    }

    private static func isRun(_ ordinals: [Int]) -> Bool {
        ordinals.count >= 3 && zip(ordinals, ordinals.dropFirst()).allSatisfy { $1 == $0 + 1 }
    }

    private static func sequence(_ ordinals: [Int], article: String?) -> String {
        if isRun(ordinals) {
            return "\(C.from) \(ordinal(ordinals[0])) \(C.to) \(ordinal(ordinals[ordinals.count - 1]))"
        }
        let words = ordinals.enumerated().map { index, value in
            guard index > 0, let article else { return ordinal(value) }
            return "\(article) \(ordinal(value))"
        }
        guard words.count > 1 else { return words.joined() }
        return words.dropLast().joined(separator: ", ") + " \(C.and) " + words[words.count - 1]
    }
}
