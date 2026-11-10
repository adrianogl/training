import Testing
import TrainingCore
import FITReader
@testable import Metrics

private let d1 = Day(iso: "2026-01-01")!
private let d2 = Day(iso: "2026-01-03")!

private func series(from: Double = 0, to: Double, step: Double = 5, _ build: (Double) -> FITSample) -> [FITSample] {
    stride(from: from, through: to, by: step).map(build)
}

@Test func vo2Smoothing() { #expect(smoothedVo2max([(d1, 56), (d2, 42)]).last!.1 == 49) }

@Test func vo2SmoothingSortsByDay() {
    let p = smoothedVo2max([(d2, 42), (d1, 56)])
    #expect(p.count == 2)
    #expect(p[0].0 == d1 && p[0].1 == 56)
    #expect(p[1].0 == d2 && p[1].1 == 49)
}

@Test func vo2SmoothingEmpty() { #expect(smoothedVo2max([]).isEmpty) }

@Test func zone2PaceIgnoresWarmup() {
    let s = series(to: 1800) { t in
        t < 600 ? FITSample(t: t, heartRate: 130, speed: 5) : FITSample(t: t, heartRate: 135, speed: 3)
    }
    let pace = zone2Pace(s, zone2: 120...140)
    #expect(pace != nil && abs(pace! - 1000.0 / 3) < 1e-9)
}

@Test func zone2PaceNeedsFiveMinutes() {
    let s = series(to: 1800) { t in
        FITSample(t: t, heartRate: (600..<800).contains(t) ? 135 : 160, speed: 3)
    }
    #expect(zone2Pace(s, zone2: 120...140) == nil)
}

@Test func thresholdPaceUsesLongSegmentsOnly() {
    let long = series(to: 1200) { t in
        (300..<700).contains(t) ? FITSample(t: t, heartRate: 166, speed: 4) : FITSample(t: t, heartRate: 140, speed: 3)
    }
    let short = series(to: 1200) { t in
        (300..<500).contains(t) ? FITSample(t: t, heartRate: 165, speed: 5) : FITSample(t: t, heartRate: 140, speed: 3)
    }
    #expect(thresholdPace([long, short], lthr: 165) == 250)
}

@Test func thresholdPaceNilWithoutSegments() {
    let run = series(to: 1200) { FITSample(t: $0, heartRate: 140, speed: 3) }
    #expect(thresholdPace([run], lthr: 165) == nil)
}

@Test func decouplingNeedsOneHour() {
    let short = series(to: 3500) { FITSample(t: $0, heartRate: 140, speed: 3) }
    #expect(decoupling(short) == nil)
    let long = series(to: 4000) { t in FITSample(t: t, heartRate: t < 2300 ? 140 : 154, speed: 3) }
    let d = decoupling(long)
    #expect(d != nil && abs(d! - (1 - 1 / 1.1) * 100) < 0.01)
}

@Test func minettiAtZeroGrade() {
    #expect(abs(minettiCost(grade: 0) - 3.6) < 1e-12)
    #expect(minettiCost(grade: 0.1) > minettiCost(grade: 0))
}

@Test func hillIndexNilWithoutClimbs() {
    let s = series(to: 1800) { t in
        FITSample(t: t, heartRate: 150, speed: 3, altitude: 100, distance: t * 3)
    }
    #expect(hillIndex(s) == nil)
}

@Test func hillIndexComparesAdjustedClimbWithFlat() {
    let flatEnd = 600.0
    let s = series(to: 1000) { t in
        if t <= flatEnd {
            return FITSample(t: t, heartRate: 150, speed: 3, altitude: 100, distance: t * 3)
        }
        let climbed = (t - flatEnd) * 2.4
        return FITSample(t: t, heartRate: 152, speed: 2.4, altitude: 100 + climbed * 0.05, distance: flatEnd * 3 + climbed)
    }
    let expected = 100 * 2.4 * minettiCost(grade: 0.05) / minettiCost(grade: 0) / 3
    let index = hillIndex(s)
    #expect(index != nil && abs(index! - expected) < 1e-6)
}

@Test func hillIndexNilWhenFlatHeartRateDiffers() {
    let s = series(to: 1000) { t in
        if t <= 600 {
            return FITSample(t: t, heartRate: 130, speed: 3, altitude: 100, distance: t * 3)
        }
        let climbed = (t - 600) * 2.4
        return FITSample(t: t, heartRate: 160, speed: 2.4, altitude: 100 + climbed * 0.05, distance: 1800 + climbed)
    }
    #expect(hillIndex(s) == nil)
}

@Test func hillIndexToleratesAltitudeNoiseOnClimb() {
    let noise = [0.3, -0.3, 0.3, 0.3, -0.3, -0.3, 0.3, -0.3]
    let flatEnd = 600.0
    let s = series(to: 1000) { t in
        if t <= flatEnd {
            return FITSample(t: t, heartRate: 150, speed: 3, altitude: 100, distance: t * 3)
        }
        let climbed = (t - flatEnd) * 2.4
        let jitter = noise[Int((t - flatEnd) / 5) % noise.count]
        return FITSample(t: t, heartRate: 152, speed: 2.4, altitude: 100 + climbed * 0.05 + jitter, distance: flatEnd * 3 + climbed)
    }
    let expected = 100 * 2.4 * minettiCost(grade: 0.05) / minettiCost(grade: 0) / 3
    let index = hillIndex(s)
    #expect(index != nil && abs(index! - expected) < 3)
}

@Test func thresholdPaceSplitsSegmentsAtPauses() {
    let before = series(from: 0, to: 175) { FITSample(t: $0, heartRate: 165, speed: 4) }
    let after = series(from: 400, to: 575) { FITSample(t: $0, heartRate: 165, speed: 4) }
    #expect(thresholdPace([before + after], lthr: 165) == nil)
}

@Test func zone2PaceCountsTimeAcrossPauses() {
    let first = series(from: 600, to: 745) { FITSample(t: $0, heartRate: 135, speed: 3) }
    let second = series(from: 1200, to: 1345) { FITSample(t: $0, heartRate: 135, speed: 3) }
    #expect(zone2Pace(first + second, zone2: 120...140) != nil)
    #expect(zone2Pace(first, zone2: 120...140) == nil)
}

@Test func hillIndexKeepsDipBeforeClimbOutOfFlat() {
    let flatEnd = 600.0
    let dipEnd = 615.0
    let s = series(to: 1000) { t in
        if t <= flatEnd {
            return FITSample(t: t, heartRate: 150, speed: 3, altitude: 100, distance: t * 3)
        }
        if t <= dipEnd {
            let dropped = (t - flatEnd) * 5
            return FITSample(t: t, heartRate: 150, speed: 5, altitude: 100 - dropped * 0.03, distance: flatEnd * 3 + dropped)
        }
        let start = flatEnd * 3 + (dipEnd - flatEnd) * 5
        let climbed = (t - dipEnd) * 2.4
        return FITSample(t: t, heartRate: 152, speed: 2.4, altitude: 100 - 2.25 + climbed * 0.08, distance: start + climbed)
    }
    let index = hillIndex(s)
    let expected = 100 * 2.4 * minettiCost(grade: 0.08) / minettiCost(grade: 0) / 3
    let previousTrimIndex = 119.437
    #expect(index != nil && abs(index! - expected) < 1)
    #expect(index! - previousTrimIndex > 0.5)
}

@Test func hillIndexAcceptsNoisyClimbNearMinimumLengthAndGrade() {
    let noise = [0.2, -0.2, 0.2, -0.2]
    let flatEnd = 600.0
    let climbSeconds = 90.0
    let s = series(to: flatEnd + climbSeconds + 200) { t in
        if t <= flatEnd {
            return FITSample(t: t, heartRate: 150, speed: 3, altitude: 100, distance: t * 3)
        }
        if t <= flatEnd + climbSeconds {
            let climbed = (t - flatEnd) * 2.5
            let jitter = noise[Int((t - flatEnd) / 5) % noise.count]
            return FITSample(t: t, heartRate: 152, speed: 2.5, altitude: 100 + climbed * 0.045 + jitter, distance: flatEnd * 3 + climbed)
        }
        let top = 100 + climbSeconds * 2.5 * 0.045
        return FITSample(t: t, heartRate: 150, speed: 3, altitude: top, distance: flatEnd * 3 + climbSeconds * 2.5 + (t - flatEnd - climbSeconds) * 3)
    }
    #expect(hillIndex(s) != nil)
}

@Test func steadyLimitIsInclusiveAtFiveMinutes() {
    let exact = series(from: 600, to: 895) { FITSample(t: $0, heartRate: 135, speed: 3) }
    let short = series(from: 600, to: 890) { FITSample(t: $0, heartRate: 135, speed: 3) }
    #expect(zone2Pace(exact, zone2: 120...140) != nil)
    #expect(zone2Pace(short, zone2: 120...140) == nil)
    let threshold = series(from: 0, to: 295) { FITSample(t: $0, heartRate: 165, speed: 4) }
    let thresholdShort = series(from: 0, to: 290) { FITSample(t: $0, heartRate: 165, speed: 4) }
    #expect(thresholdPace([threshold], lthr: 165) == 250)
    #expect(thresholdPace([thresholdShort], lthr: 165) == nil)
}
