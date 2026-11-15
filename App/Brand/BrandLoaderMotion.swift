import Foundation

enum BrandLoaderMotion {
    static func head(at seconds: Double, lap: Double = BrandLoaderConstants.lapSeconds) -> Double {
        let phase = cycle(seconds, period: lap)
        return (1 - cos(Double.pi * phase)) / 2
    }

    static func glow(at seconds: Double, period: Double = BrandLoaderConstants.glowSeconds) -> Double {
        (1 - cos(2 * Double.pi * cycle(seconds, period: period))) / 2
    }

    static func reducedOpacity(at seconds: Double) -> Double {
        let minimum = BrandLoaderConstants.reducedMotionMinimumOpacity
        return minimum + (1 - minimum) * glow(at: seconds, period: BrandLoaderConstants.reducedMotionSeconds)
    }

    private static func cycle(_ seconds: Double, period: Double) -> Double {
        guard period > 0 else { return 0 }
        let value = seconds.truncatingRemainder(dividingBy: period) / period
        return value < 0 ? value + 1 : value
    }
}
