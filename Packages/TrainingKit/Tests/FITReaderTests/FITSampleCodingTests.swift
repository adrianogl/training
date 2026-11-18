import Foundation
import Testing
@testable import FITReader

private let samples = [
    FITSample(t: 0, heartRate: 142, speed: 3.02, altitude: 802.5, distance: 12, cadence: 171, stanceTime: 240, lat: -19.900_213_4, lon: -43.900_045_1),
    FITSample(t: 5, heartRate: nil, speed: nil, altitude: nil, distance: 27),
    FITSample(t: 3_605, heartRate: 188, speed: 4.4, altitude: nil, distance: 12_345.6, cadence: nil, stanceTime: nil, lat: nil, lon: nil),
]

@Test func binarySamplesRoundTrip() throws {
    let decoded = try #require(FITSampleCoding.decode(FITSampleCoding.encode(samples)))
    #expect(decoded.count == samples.count)
    for (read, original) in zip(decoded, samples) {
        #expect(abs(read.t - original.t) < 0.001)
        #expect(read.heartRate == original.heartRate)
        #expect(abs((read.speed ?? -1) - (original.speed ?? -1)) < 0.0001)
        #expect(abs((read.distance ?? -1) - (original.distance ?? -1)) < 0.01)
        #expect((read.cadence == nil) == (original.cadence == nil))
        #expect(read.lat == original.lat && read.lon == original.lon)
    }
}

@Test func binaryIsSmallerThanJSON() throws {
    let many = (0..<720).map { FITSample(t: Double($0) * 5, heartRate: 150, speed: 3.2, altitude: 800, distance: Double($0) * 16, cadence: 172, stanceTime: 238, lat: -19.9, lon: -43.9) }
    let json = try JSONEncoder().encode(many)
    #expect(FITSampleCoding.encode(many).count * 2 < json.count)
}

@Test func oldJSONSamplesStillDecode() throws {
    let json = try JSONEncoder().encode(samples)
    #expect(FITSampleCoding.decode(json) == samples)
    #expect(FITSampleCoding.decode(Data([0x46, 0x53, 0x42, 0x31, 9, 0, 0, 0])) == nil)
}
