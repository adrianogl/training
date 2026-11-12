import Foundation
import FITSwiftSDK
import Testing
@testable import FITReader

@Test func readsSessionTimeInZone() throws {
    let mesgs: [Mesg] = [
        try FITFixtureBuilder.timeInZone(reference: .lap, boundaries: [90, 110, 120, 130, 140, 150], threshold: 150),
        try FITFixtureBuilder.timeInZone(reference: .session, boundaries: [110, 130, 140, 150, 160, 190], threshold: 170),
        try FITFixtureBuilder.timeInZone(reference: .lap, boundaries: [91, 111, 121, 131, 141, 151], threshold: 151),
    ]
    let info = try #require(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 30, msg140: nil, extra: mesgs)).zoneInfo)
    #expect(info == HeartRateZoneInfo(
        thresholdHeartRate: 170,
        maxHeartRate: 190,
        restingHeartRate: 48,
        calcType: 3,
        floors: [110, 130, 140, 150, 160]
    ))
}

@Test func invalidZoneValuesBecomeNil() throws {
    let mesgs: [Mesg] = [
        try FITFixtureBuilder.timeInZone(
            reference: .session,
            boundaries: [110, 130, 255, 150, 160, 190],
            threshold: 255,
            maxHeartRate: 255,
            restingHeartRate: 255,
            calcType: .invalid
        ),
    ]
    let info = try #require(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 30, msg140: nil, extra: mesgs)).zoneInfo)
    #expect(info.thresholdHeartRate == nil)
    #expect(info.maxHeartRate == nil)
    #expect(info.restingHeartRate == nil)
    #expect(info.calcType == nil)
    #expect(info.floors.isEmpty)
}

@Test func runWithoutTimeInZoneHasNoZoneInfo() throws {
    #expect(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 30, msg140: nil)).zoneInfo == nil)
}

@Test func processingVersionIsThree() {
    #expect(FITReaderConstants.processingVersion == 3)
}
