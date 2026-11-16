import Foundation
import GarminAPI
import Insights
import MFIT

enum TrainerMFITStrength {
    static func sessions(program: MFITProgram?, schedule: StrengthSchedule) -> [TrainerStrengthSession] {
        guard let program else { return [] }
        return program.workouts.compactMap { workout -> TrainerStrengthSession? in
            guard let weekday = schedule.weekday(for: workout) else { return nil }
            let entries = workout.blocks.flatMap { block in block.exercises.map { (category: $0.category, sets: block.sets) } }
            let legs = StrengthMuscles.isLegDay(entries)
            let group: TrainerStrengthGroup = legs ? .lower : StrengthMuscles.upperShare(entries) >= 0.5 ? .upper : .fullBody
            return TrainerStrengthSession(id: Self.id(workout.id), weekday: weekday + 1, group: group, legLoad: legs ? .heavy : .light, name: workout.title)
        }
        .sorted { $0.weekday < $1.weekday }
    }

    static func same(_ lhs: [TrainerStrengthSession], _ rhs: [TrainerStrengthSession]) -> Bool {
        let key: (TrainerStrengthSession) -> String = { "\($0.weekday)|\($0.group.rawValue)|\($0.legLoad.rawValue)|\($0.name)" }
        return lhs.map(key).sorted() == rhs.map(key).sorted()
    }

    static func caption(_ session: TrainerStrengthSession) -> String {
        "\(TrainerMFITConstants.regionNames[session.group] ?? "") · \(session.legLoad == .heavy ? TrainerMFITConstants.heavyLeg : TrainerMFITConstants.lightLeg)"
    }

    private static func id(_ workoutId: Int64) -> UUID {
        let hex = String(format: "%012llx", UInt64(bitPattern: workoutId))
        return UUID(uuidString: "00000000-0000-4000-8000-" + String(hex.suffix(12))) ?? UUID()
    }
}
