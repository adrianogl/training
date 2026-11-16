import Foundation
import GarminAPI
import MFIT

enum StrengthWatchLoads {
    static func records(sets: [StrengthSet], blocks: [StrengthBlock], workoutId: Int64, day: String) -> [MFITLoadRecord] {
        let queue: [(name: String, category: String?)] = blocks.flatMap { block in
            (0..<max(block.sets, 1)).flatMap { _ in block.exercises.map { (name: $0.name, category: $0.category) } }
        }
        var pointer = 0
        var used = Set<Int>()
        var loads: [String: [Double]] = [:]
        var order: [String] = []
        for set in sets {
            guard let category = set.category else { continue }
            let matches: (Int) -> Bool = { !used.contains($0) && queue[$0].category == category }
            guard let found = (pointer..<queue.count).first(where: matches) ?? (0..<min(pointer, queue.count)).first(where: matches) else { continue }
            used.insert(found)
            pointer = found + 1
            guard let weight = set.weight, weight > 0 else { continue }
            let name = queue[found].name
            if loads[name] == nil { order.append(name) }
            loads[name, default: []].append(weight)
        }
        return order.map { name in
            MFITLoadRecord(exercise: name, key: MFITParser.exerciseKey(name), day: day, loads: loads[name] ?? [], workoutId: workoutId, fromWatch: true)
        }
    }
}
