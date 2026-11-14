import FITReader
import Foundation
import Storage
import Testing
@testable import Insights

@Suite struct WorkoutKindClassifierTests {
    private func record(_ name: String, meters: Double, workoutName: String? = nil, structure: WorkoutStructure? = nil) -> ActivityRecord {
        ActivityRecord(
            activityId: 1, typeKey: "running", name: name, start: .now, distance: meters, duration: meters / 3,
            workoutName: workoutName, structureData: structure.map { try! JSONEncoder().encode($0) }
        )
    }

    private func kind(_ record: ActivityRecord) -> RunKind {
        classifyRun(record, longGoalKm: 16, raceGoalKms: [10])
    }

    @Test func prescribedRepeatsAreIntervals() {
        let steps = [
            PrescribedStep(index: 0, intensity: .active, duration: .distance(meters: 1_000), target: .open),
            PrescribedStep(index: 1, intensity: .recovery, duration: .time(seconds: 90), target: .open),
            PrescribedStep(index: 2, intensity: .other, duration: .repeatSteps(fromIndex: 0, count: 6), target: .open),
        ]
        let structure = WorkoutStructure(prescription: WorkoutPrescription(name: "Rodagem", steps: steps))

        #expect(kind(record("Corrida", meters: 9_000, structure: structure)) == .intervals)
    }

    @Test func namesDecideWhenThereIsNoPrescription() {
        #expect(kind(record("Corrida", meters: 8_000, workoutName: "Longão progressivo")) == .long)
        #expect(kind(record("Corrida", meters: 8_000, workoutName: "Ritmo 5k")) == .tempo)
        #expect(kind(record("Corrida", meters: 8_000, workoutName: "Regenerativo")) == .easy)
        #expect(kind(record("Corrida", meters: 8_000, workoutName: "Teste de 10 km")) == .race)
        #expect(kind(record("Corrida", meters: 8_000, workoutName: "Tiros curtos")) == .intervals)
    }

    @Test func distanceDecidesWhenTheNameSaysNothing() {
        #expect(kind(record("Corrida", meters: 12_660)) == .easy)
        #expect(kind(record("Corrida", meters: 16_200)) == .long)
        #expect(kind(record("Corrida", meters: 10_050)) == .race)
        #expect(kind(record("Corrida", meters: 9_000)) == .easy)
    }

    @Test func repeatedActiveLapsAreIntervals() {
        let active = LapSummary(intensity: .active, startOffset: 0, timerSeconds: 240, distance: 1_000)
        let recovery = LapSummary(intensity: .recovery, startOffset: 0, timerSeconds: 90, distance: 250)
        let structure = WorkoutStructure(laps: [active, recovery, active, recovery, active])

        #expect(kind(record("Corrida", meters: 7_000, structure: structure)) == .intervals)
    }

    @Test func longRunRuleUsesNameAndDistance() {
        #expect(isLongRun(name: "Longão", distanceMeters: 5_000, goalKm: 16))
        #expect(isLongRun(name: "Corrida", distanceMeters: 14_200, goalKm: 16))
        #expect(!isLongRun(name: "Corrida", distanceMeters: 13_900, goalKm: 16))
        #expect(!isLongRun(name: "Rodagem", distanceMeters: 16_000, goalKm: 16))
        #expect(!isLongRun(name: "Tiros", distanceMeters: 16_000, goalKm: 16))
    }
}
