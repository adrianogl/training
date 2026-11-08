import FITReader
import Testing
@testable import trAIning

@Suite struct ChartDataTests {
    @Test func heartRateSeriesSkipsNil() {
        let samples = [
            FITSample(t: 0, heartRate: 120),
            FITSample(t: 1),
            FITSample(t: 2, heartRate: 130),
            FITSample(t: 3, speed: 3),
            FITSample(t: 4, heartRate: 140),
        ]

        let series = ChartData.heartRateSeries(samples)

        #expect(series.map { $0.t } == [0, 2, 4])
        #expect(series.map { $0.bpm } == [120, 130, 140])
    }

    @Test func zoneSharesSumToOne() throws {
        let shares = ChartData.zoneShares([60, 120, 600, 300, 120])

        try #require(shares.count == 5)
        #expect(abs(shares.reduce(0, +) - 1) < 1e-9)
        #expect(abs(shares[2] - 600.0 / 1_200) < 1e-9)

        let zeros = ChartData.zoneShares([0, 0, 0, 0, 0])
        #expect(zeros == [0, 0, 0, 0, 0])
        #expect(zeros.allSatisfy { !$0.isNaN })
        #expect(ChartData.zoneShares([]).isEmpty)
    }
}
