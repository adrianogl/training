import CoreGraphics

enum BrandLoaderConstants {
    static let large = BrandLoaderMetrics(
        side: 64, ringGap: -0.75, ringLineWidth: 2, traceLength: 0.32, borderWidth: 1.5, glowRadius: 18, shadowRadii: [4, 14, 28]
    )
    static let regular = BrandLoaderMetrics(
        side: 40, ringGap: -0.75, ringLineWidth: 2, traceLength: 0.32, borderWidth: 1.5, glowRadius: 12, shadowRadii: [3, 9, 18]
    )
    static let mini = BrandLoaderMetrics(
        side: 16, ringGap: -0.5, ringLineWidth: 1.5, traceLength: 0.28, borderWidth: 1, glowRadius: 8, shadowRadii: [2, 5, 8]
    )
    static let shadowOpacities: [Double] = [0.7, 0.45, 0.3]
    static let ringOpacity = 0.9
    static let tailOpacity = 0.25
    static let lapSeconds = 2.0
    static let glowSeconds = 2.0
    static let glowPeakOpacity = 0.14
    static let progressGlowOpacity = 0.07
    static let reducedMotionSeconds = 3.0
    static let reducedMotionMinimumOpacity = 0.55
    static let fontRatio: CGFloat = 0.375
    static let progressAnimationSeconds = 0.15
}
