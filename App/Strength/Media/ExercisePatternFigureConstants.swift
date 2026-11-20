import SwiftUI

enum ExercisePatternFigureConstants {
    static let viewBox = CGSize(width: 180, height: 120)
    static let figureOffset = CGPoint(x: 38.5, y: -2.5)
    static let figureScale: CGFloat = 0.88
    static let frameMargin: CGFloat = 4
    static let ground = [CGPoint(x: -10, y: 128), CGPoint(x: 130, y: 128)]
    static let groundOpacity = 0.35
    static let groundWidth: CGFloat = 2.5
    static let bodyWidth: CGFloat = 5
    static let armWidth: CGFloat = 4
    static let propWidth: CGFloat = 3
    static let headRadius: CGFloat = 8
    static let weightRadius: CGFloat = 6
    static let cycleSeconds = 2.6
    static let easing = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.45, y: 0), endControlPoint: UnitPoint(x: 0.55, y: 1))
    static let accessibilityLabel = "Desenho do movimento do exercício"
}
