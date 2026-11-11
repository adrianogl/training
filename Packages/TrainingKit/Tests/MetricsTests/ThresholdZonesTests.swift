import Testing
import TrainingCore
import FITReader
@testable import Metrics

private func steady(_ heartRate: Int, from start: Int, seconds: Int) -> [FITSample] {
    (0..<seconds).map { FITSample(t: Double(start + $0), heartRate: heartRate) }
}

@Suite struct ThresholdZonesTests {
    @Test func thresholdZonesFollowFriel() {
        let zones = thresholdZones(thresholdHeartRate: 160)
        #expect(zones.floors == [0, 136, 144, 152, 160])
        #expect(zones.maxHeartRate == nil)
    }

    @Test func zoneSecondsSplitsByFloor() throws {
        let samples = steady(130, from: 0, seconds: 60) + steady(150, from: 60, seconds: 60) + steady(165, from: 120, seconds: 31)
        let seconds = try #require(zoneSeconds(samples, zones: thresholdZones(thresholdHeartRate: 160)))
        #expect(seconds == [60, 0, 60, 0, 30])
    }

    @Test func zoneSecondsCapsGaps() throws {
        let samples = [FITSample(t: 0, heartRate: 130), FITSample(t: 120, heartRate: 130)]
        let seconds = try #require(zoneSeconds(samples, zones: thresholdZones(thresholdHeartRate: 160)))
        #expect(seconds == [10, 0, 0, 0, 0])
    }

    @Test func zoneSecondsNilWithoutHeartRate() {
        let samples = [FITSample(t: 0), FITSample(t: 1)]
        #expect(zoneSeconds(samples, zones: thresholdZones(thresholdHeartRate: 160)) == nil)
        #expect(zoneSeconds([], zones: thresholdZones(thresholdHeartRate: 160)) == nil)
    }

    @Test func zoneSecondsIgnoresZeroHeartRate() throws {
        let samples = steady(0, from: 0, seconds: 30) + steady(150, from: 30, seconds: 31)
        let seconds = try #require(zoneSeconds(samples, zones: thresholdZones(thresholdHeartRate: 160)))
        #expect(seconds == [0, 0, 30, 0, 0])
        #expect(zoneSeconds(steady(0, from: 0, seconds: 30), zones: thresholdZones(thresholdHeartRate: 160)) == nil)
    }

    @Test func divergenceBothDirections() {
        #expect(zoneDivergence(watchZone5Floor: 154, thresholdHeartRate: 160) == -6)
        #expect(zoneDivergence(watchZone5Floor: 175, thresholdHeartRate: 165) == 10)
        #expect(zoneDivergence(watchZone5Floor: 158, thresholdHeartRate: 160) == nil)
        #expect(zoneDivergence(watchZone5Floor: nil, thresholdHeartRate: 160) == nil)
        #expect(zoneDivergence(watchZone5Floor: 160, thresholdHeartRate: nil) == nil)
    }
}
