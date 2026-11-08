import Foundation
import Testing
@testable import FITReader

@Test func readsVo2maxFromMessage140() throws {
    let s = try FITReader.read(fit: FITFixtureBuilder.run(seconds: 1200, msg140: [7: 1024809, 9: 3456, 17: -1]))
    #expect(abs(s.physio!.vo2max! - 54.73) < 0.01)
    #expect(s.physio!.recoveryMinutes == 3456 && s.physio!.performanceCondition == -1)
}

@Test func missingOrZeroVo2maxIsNil() throws {
    #expect(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 600, msg140: nil)).physio == nil)
    #expect(try FITReader.read(fit: FITFixtureBuilder.run(seconds: 600, msg140: [7: 0])).physio?.vo2max == nil)
}

@Test func resamplesToFiveSeconds() throws {
    let samples = try FITReader.read(fit: FITFixtureBuilder.run(seconds: 1200, msg140: nil)).samples
    #expect(samples.count == 240)
    #expect(samples[0].t == 0 && samples[1].t == 5)
    #expect(samples[0].heartRate == 122)
    #expect(abs(samples[0].speed! - 3.2) < 0.001)
    #expect(samples[1].distance == 27)
}

@Test func routeIsCappedAt500Points() throws {
    let s = try FITReader.read(fit: FITFixtureBuilder.run(seconds: 5000, msg140: nil))
    #expect(s.route.count <= 500)
    #expect(s.route.count > 50)
    #expect(abs(s.route[0].lat - (-300_000_000.0 * 180 / 2_147_483_648)) < 0.01)
}

@Test func readsFromZip() throws {
    let fit = try FITFixtureBuilder.run(seconds: 600, msg140: [7: 1024809])
    let fromZip = try FITReader.read(zip: FITFixtureBuilder.zip(containing: fit))
    let direct = try FITReader.read(fit: fit)
    #expect(fromZip.samples == direct.samples)
    #expect(fromZip.route == direct.route)
    #expect(fromZip.physio == direct.physio)
}

@Test func zipWithoutFitEntryThrows() throws {
    let zip = try FITFixtureBuilder.zip(containing: Data("x".utf8), entryName: "notes.txt")
    #expect(throws: FITReaderError.self) { try FITReader.read(zip: zip) }
}

@Test func garbageFitThrows() {
    #expect(throws: FITReaderError.self) { try FITReader.read(fit: Data([1, 2, 3, 4])) }
}
