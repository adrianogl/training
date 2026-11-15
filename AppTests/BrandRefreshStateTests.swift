import CoreGraphics
import Testing
@testable import trAIning

@Suite struct BrandRefreshStateTests {
    @Test func startsIdle() {
        let state = BrandRefreshState(threshold: 80)

        #expect(state.phase == .idle)
        #expect(state.fraction == 0)
        #expect(!state.isActive)
    }

    @Test func pullingMapsOverscrollToFraction() {
        var state = BrandRefreshState(threshold: 80)

        #expect(state.update(overscroll: 20, isInteracting: true) == nil)

        #expect(state.phase == .pulling)
        #expect(state.fraction == 0.25)
        #expect(!state.isArmed)
    }

    @Test func fractionIsCappedAtOne() {
        var state = BrandRefreshState(threshold: 80)

        _ = state.update(overscroll: 200, isInteracting: true)

        #expect(state.fraction == 1)
        #expect(state.isArmed)
    }

    @Test func armsAtThreshold() {
        var state = BrandRefreshState(threshold: 80)

        _ = state.update(overscroll: 79.9, isInteracting: true)
        #expect(!state.isArmed)
        _ = state.update(overscroll: 80, isInteracting: true)
        #expect(state.isArmed)
    }

    @Test func releasingAboveThresholdStartsSync() {
        var state = BrandRefreshState(threshold: 80)
        _ = state.update(overscroll: 95, isInteracting: true)

        #expect(state.update(overscroll: 95, isInteracting: false) == .started)

        #expect(state.phase == .syncing)
        #expect(state.fraction == 1)
    }

    @Test func releasingBelowThresholdCancels() {
        var state = BrandRefreshState(threshold: 80)
        _ = state.update(overscroll: 40, isInteracting: true)

        #expect(state.update(overscroll: 40, isInteracting: false) == .cancelled)

        #expect(state.phase == .idle)
        #expect(state.fraction == 0)
    }

    @Test func bounceAfterReleaseDoesNotRestartOrCancel() {
        var state = BrandRefreshState(threshold: 80)
        _ = state.update(overscroll: 95, isInteracting: true)
        _ = state.update(overscroll: 95, isInteracting: false)

        #expect(state.update(overscroll: 10, isInteracting: false) == nil)
        #expect(state.update(overscroll: 120, isInteracting: true) == nil)

        #expect(state.phase == .syncing)
    }

    @Test func returningToTopWhileDraggingGoesBackToIdle() {
        var state = BrandRefreshState(threshold: 80)
        _ = state.update(overscroll: 60, isInteracting: true)

        _ = state.update(overscroll: 0, isInteracting: true)

        #expect(state.phase == .idle)
        #expect(state.update(overscroll: 0, isInteracting: false) == nil)
    }

    @Test func idleWithoutPullIgnoresRelease() {
        var state = BrandRefreshState(threshold: 80)

        #expect(state.update(overscroll: 0, isInteracting: false) == nil)
        #expect(state.phase == .idle)
    }

    @Test func finishThenSettleWalksThroughDoneToIdle() {
        var state = BrandRefreshState(threshold: 80)
        _ = state.update(overscroll: 90, isInteracting: true)
        _ = state.update(overscroll: 90, isInteracting: false)

        state.finish()
        #expect(state.phase == .done)
        #expect(state.isActive)

        state.settle()
        #expect(state.phase == .idle)
        #expect(state.pull == 0)
    }

    @Test func finishOutsideSyncingIsIgnored() {
        var state = BrandRefreshState(threshold: 80)

        state.finish()

        #expect(state.phase == .idle)
    }

    @Test func negativeOverscrollIsTreatedAsZero() {
        var state = BrandRefreshState(threshold: 80)

        _ = state.update(overscroll: -30, isInteracting: true)

        #expect(state.phase == .idle)
        #expect(state.pull == 0)
    }
}

@Suite struct BrandLoaderMotionTests {
    @Test func headStartsAtZeroAndAdvancesMonotonicallyOverLap() {
        let samples = stride(from: 0.0, to: 2.0, by: 0.1).map { BrandLoaderMotion.head(at: $0, lap: 2) }

        #expect(samples.first == 0)
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(samples.last! < 1)
    }

    @Test func headEasesInAndOut() {
        let early = BrandLoaderMotion.head(at: 0.1, lap: 2)
        let middle = BrandLoaderMotion.head(at: 1.0, lap: 2)

        #expect(early < 0.05)
        #expect(abs(middle - 0.5) < 0.0001)
    }

    @Test func glowPeaksMidPeriod() {
        #expect(BrandLoaderMotion.glow(at: 0, period: 2) == 0)
        #expect(abs(BrandLoaderMotion.glow(at: 1, period: 2) - 1) < 0.0001)
    }

    @Test func reducedOpacityStaysWithinBounds() {
        let values = stride(from: 0.0, to: 6.0, by: 0.25).map { BrandLoaderMotion.reducedOpacity(at: $0) }

        #expect(values.allSatisfy { $0 >= BrandLoaderConstants.reducedMotionMinimumOpacity && $0 <= 1 })
    }
}
