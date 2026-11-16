import CoreGraphics

enum TrackGlyphConstants {
    static let canvas: CGFloat = 100
    static let outer = CGRect(x: 15, y: 26, width: 70, height: 48)
    static let inner = CGRect(x: 24, y: 35, width: 52, height: 30)
    static let runner = CGRect(x: 71, y: 26, width: 10, height: 10)
    static let outerLineWidth: CGFloat = 6
    static let innerLineWidth: CGFloat = 2.5
    static let innerOpacity = 0.35
    static let loaderTrackOpacity = 0.22
    static let runnerRestFraction = 0.1388
}
