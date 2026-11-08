import FITReader
import Foundation
import Storage
import TrainingCore

enum WorkoutDetailFixtures {
    static let base = Date(timeIntervalSince1970: 1_793_000_000)
    static let tiroSpeed = 1_000.0 / 245

    static func day(_ date: Date) -> String {
        Day.today(in: TimeZone(secondsFromGMT: 0)!, now: date).iso
    }

    static func intervalStructure() -> WorkoutStructure {
        let steps = [
            PrescribedStep(index: 0, intensity: .warmup, duration: .distance(meters: 1_000), target: .open),
            PrescribedStep(index: 1, intensity: .active, duration: .distance(meters: 1_000), target: .speed(low: 1_000.0 / 250, high: 1_000.0 / 240)),
            PrescribedStep(index: 2, intensity: .recovery, duration: .time(seconds: 120), target: .open),
            PrescribedStep(index: 3, intensity: .active, duration: .repeatSteps(fromIndex: 1, count: 3), target: .open),
            PrescribedStep(index: 4, intensity: .cooldown, duration: .distance(meters: 1_000), target: .open),
        ]
        var laps: [LapSummary] = []
        var offset = 0.0
        func lap(_ step: Int, _ intensity: StepIntensity, seconds: Double, distance: Double, hr: Int) {
            laps.append(LapSummary(
                stepIndex: step, intensity: intensity, startOffset: offset, timerSeconds: seconds,
                distance: distance, avgSpeed: distance / seconds, avgHeartRate: hr, maxHeartRate: hr + 6
            ))
            offset += seconds
        }
        lap(0, .warmup, seconds: 360, distance: 1_000, hr: 130)
        for _ in 0..<3 {
            lap(1, .active, seconds: 245, distance: 1_000, hr: 168)
            lap(2, .recovery, seconds: 120, distance: 300, hr: 140)
        }
        lap(4, .cooldown, seconds: 380, distance: 1_000, hr: 135)
        return WorkoutStructure(
            prescription: WorkoutPrescription(name: "Tiros 3 x 1 km", steps: steps),
            laps: laps
        )
    }

    static func freeStructure(kilometers: Int, secondsPerKm: Double = 330, hr: Int = 150) -> WorkoutStructure {
        let laps = (0..<kilometers).map { index in
            LapSummary(
                startOffset: Double(index) * secondsPerKm, timerSeconds: secondsPerKm, distance: 1_000,
                avgSpeed: 1_000 / secondsPerKm, avgHeartRate: hr, maxHeartRate: hr + 8
            )
        }
        return WorkoutStructure(laps: laps)
    }

    static func samples(kilometers: Double, secondsPerKm: Double, step: Double = 5) -> [FITSample] {
        let speed = 1_000 / secondsPerKm
        let total = kilometers * secondsPerKm
        return stride(from: 0.0, through: total, by: step).map { t in
            FITSample(t: t, heartRate: 140 + Int(t / 120), speed: speed, distance: speed * t)
        }
    }

    static func encoded<T: Encodable>(_ value: T) -> Data {
        try! JSONEncoder().encode(value)
    }

    static func run(
        id: Int64,
        daysAgo: Double = 0,
        meters: Double,
        workoutName: String? = nil,
        structure: WorkoutStructure? = nil,
        samples: [FITSample]? = nil,
        processingVersion: Int = 2
    ) -> ActivityRecord {
        let start = base.addingTimeInterval(-daysAgo * 86_400)
        return ActivityRecord(
            activityId: id, typeKey: "running", name: "Corrida", start: start,
            distance: meters, duration: meters * 0.33, movingDuration: meters * 0.33,
            averageHR: 150, maxHR: 172, activityTrainingLoad: 80,
            samplesData: samples.map(encoded), localDay: day(start), processingVersion: processingVersion,
            workoutName: workoutName, structureData: structure.map(encoded)
        )
    }
}
