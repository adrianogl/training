import CoreGraphics

struct BrandLoaderMetrics: Equatable {
    let side: CGFloat
    let ringGap: CGFloat
    let ringLineWidth: CGFloat
    let traceLength: Double
    let borderWidth: CGFloat
    let glowRadius: CGFloat
    let shadowRadii: [CGFloat]
}

enum BrandLoaderSize: Equatable {
    case large
    case regular
    case mini

    var metrics: BrandLoaderMetrics {
        switch self {
        case .large: BrandLoaderConstants.large
        case .regular: BrandLoaderConstants.regular
        case .mini: BrandLoaderConstants.mini
        }
    }
}
