import Foundation
import FITSwiftSDK
import Testing
@testable import FITReader

private func paceWorkout() throws -> [Mesg] {
    var mesgs: [Mesg] = [
        try FITFixtureBuilder.workout(name: "Fartlek de teste", description: "Ritmo sintético para fixture"),
        try FITFixtureBuilder.step(index: 0, intensity: .warmup, meters: 3000, speed: (3.0, 3.2)),
        try FITFixtureBuilder.step(index: 1, intensity: .active, meters: 7000, speed: (3.9, 4.15)),
        try FITFixtureBuilder.step(index: 2, intensity: .recovery, seconds: 240),
        try FITFixtureBuilder.step(index: 3, intensity: .active, meters: 3000, speed: (3.9, 4.15)),
    ]
    let plan: [(step: UInt16, intensity: Intensity, laps: Int, seconds: Double, meters: Double)] = [
        (0, .warmup, 3, 320, 1000),
        (1, .active, 7, 250, 1000),
        (2, .recovery, 1, 240, 500),
        (3, .active, 1, 250, 1000),
    ]
    var offset: UInt32 = 0
    for block in plan {
        for _ in 0..<block.laps {
            mesgs.append(try FITFixtureBuilder.lap(
                offset: offset,
                seconds: block.seconds,
                meters: block.meters,
                stepIndex: block.step,
                intensity: block.intensity,
                trigger: block.step == 2 ? .time : .distance,
                heartRate: (150, 165)
            ))
            offset += UInt32(block.seconds)
        }
    }
    mesgs.append(try FITFixtureBuilder.lap(offset: offset, seconds: 2, meters: 4, stepIndex: nil, trigger: .sessionEnd))
    return mesgs
}

@Test func readsPaceStepsAndLaps() throws {
    let structure = try FITReader.read(fit: FITFixtureBuilder.run(seconds: 60, msg140: nil, extra: paceWorkout())).structure
    let prescription = try #require(structure.prescription)
    #expect(prescription.name == "Fartlek de teste")
    #expect(prescription.description == "Ritmo sintético para fixture")
    #expect(prescription.steps.count == 4)
    #expect(prescription.steps.map(\.index) == [0, 1, 2, 3])
    #expect(prescription.steps[0].intensity == .warmup)
    #expect(prescription.steps[0].duration == .distance(meters: 3000))
    guard case let .speed(low, high) = prescription.steps[1].target else {
        Issue.record("esperava alvo de velocidade, veio \(prescription.steps[1].target)")
        return
    }
    #expect(abs(low - 3.9) < 0.001 && abs(high - 4.15) < 0.001)
    #expect(prescription.steps[2].intensity == .recovery)
    #expect(prescription.steps[2].duration == .time(seconds: 240))
    #expect(prescription.steps[2].target == .open)

    #expect(structure.laps.count == 13)
    #expect(structure.laps[3].stepIndex == 1)
    #expect(structure.laps[3].intensity == .active)
    #expect(structure.laps[3].trigger == "distance")
    #expect(structure.laps[1].startOffset == 320)
    #expect(structure.laps[3].startOffset == 960)
    #expect(structure.laps[3].timerSeconds == 250)
    #expect(structure.laps[3].distance == 1000)
    #expect(abs(structure.laps[3].avgSpeed! - 4.0) < 0.001)
    #expect(structure.laps[3].avgHeartRate == 150 && structure.laps[3].maxHeartRate == 165)
    #expect(structure.laps[10].trigger == "time")
    #expect(structure.laps[12].stepIndex == nil)
    #expect(structure.laps[12].trigger == "session_end")
    #expect(structure.laps[12].avgHeartRate == nil)
}

@Test func readsRepeatStep() throws {
    let mesgs: [Mesg] = [
        try FITFixtureBuilder.workout(name: "Tiros de teste", description: nil),
        try FITFixtureBuilder.step(index: 0, intensity: .warmup, seconds: 600),
        try FITFixtureBuilder.step(index: 1, intensity: .active, meters: 400, speed: (4.5, 4.8)),
        try FITFixtureBuilder.step(index: 2, intensity: .recovery, seconds: 90),
        try FITFixtureBuilder.repeatStep(index: 3, fromIndex: 1, count: 6),
    ]
    let prescription = try #require(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 30, msg140: nil, extra: mesgs)).structure.prescription)
    #expect(prescription.description == nil)
    #expect(prescription.steps.count == 4)
    #expect(prescription.steps[3].duration == .repeatSteps(fromIndex: 1, count: 6))
    #expect(prescription.steps[3].target == .open)
}

@Test func readsHeartRateTargets() throws {
    let mesgs: [Mesg] = [
        try FITFixtureBuilder.workout(name: "FC de teste", description: nil),
        try FITFixtureBuilder.step(index: 0, seconds: 900, heartRate: (245, 260)),
        try FITFixtureBuilder.step(index: 1, seconds: 900, heartRate: (70, 80)),
        try FITFixtureBuilder.step(index: 2, seconds: 900, heartRateZone: 2),
    ]
    let steps = try #require(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 30, msg140: nil, extra: mesgs)).structure.prescription).steps
    #expect(steps[0].target == .heartRateBpm(low: 145, high: 160))
    #expect(steps[1].target == .heartRatePercentMax(low: 70, high: 80))
    #expect(steps[2].target == .heartRateZone(2))
}

@Test func freeRunHasNoPrescription() throws {
    let laps = [
        try FITFixtureBuilder.lap(offset: 0, seconds: 300, meters: 1000, stepIndex: nil),
        try FITFixtureBuilder.lap(offset: 300, seconds: 290, meters: 1000, stepIndex: nil),
    ]
    let structure = try FITReader.read(fit: FITFixtureBuilder.run(seconds: 30, msg140: nil, extra: laps)).structure
    #expect(structure.prescription == nil)
    #expect(structure.laps.count == 2)
    #expect(structure.laps[1].startOffset == 300)
    #expect(structure.laps.allSatisfy { $0.stepIndex == nil })
}

@Test func runWithoutLapsHasEmptyStructure() throws {
    let structure = try FITReader.read(fit: FITFixtureBuilder.run(seconds: 30, msg140: nil)).structure
    #expect(structure == WorkoutStructure())
}
