import Insights
import SwiftUI

enum ExercisePatternMotion {
    static func progress(at seconds: TimeInterval, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 1 }
        let cycle = ExercisePatternFigureConstants.cycleSeconds
        let phase = seconds.truncatingRemainder(dividingBy: cycle) / cycle
        let leg = phase < 0.5 ? phase * 2 : (1 - phase) * 2
        return ExercisePatternFigureConstants.easing.value(at: leg)
    }
}

struct ExercisePatternFigure: View {
    let pattern: MovementPattern
    private let fixedProgress: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(pattern: MovementPattern) {
        self.pattern = pattern
        fixedProgress = nil
    }

    init(pattern: MovementPattern, progress: Double) {
        self.pattern = pattern
        fixedProgress = progress
    }

    var body: some View {
        Group {
            if let fixedProgress {
                figure(progress: fixedProgress)
            } else if reduceMotion {
                figure(progress: ExercisePatternMotion.progress(at: 0, reduceMotion: true))
            } else {
                TimelineView(.animation) { context in
                    figure(progress: ExercisePatternMotion.progress(at: context.date.timeIntervalSinceReferenceDate, reduceMotion: false))
                }
            }
        }
        .aspectRatio(ExercisePatternFigureConstants.viewBox.width / ExercisePatternFigureConstants.viewBox.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ExercisePatternFigureConstants.accessibilityLabel)
    }

    private func figure(progress: Double) -> some View {
        let pose = ExercisePatternPoses.pose(pattern, progress: progress)
        let props = ExercisePatternPoses.props(pattern)
        let showsGround = ExercisePatternPoses.showsGround(pattern)
        return Canvas { context, size in
            let constants = ExercisePatternFigureConstants.self
            let scale = min(size.width / constants.viewBox.width, size.height / constants.viewBox.height)
            context.translateBy(
                x: (size.width - constants.viewBox.width * scale) / 2,
                y: (size.height - constants.viewBox.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: constants.figureOffset.x, y: constants.figureOffset.y)
            context.scaleBy(x: constants.figureScale, y: constants.figureScale)
            if showsGround {
                context.stroke(polyline(constants.ground), with: .color(BrandColors.dim.opacity(constants.groundOpacity)), style: stroke(constants.groundWidth))
            }
            for prop in props {
                context.stroke(polyline(prop), with: .color(BrandColors.dim), style: stroke(constants.propWidth))
            }
            if !pose.backArm.isEmpty {
                context.stroke(polyline(pose.backArm), with: .color(BrandColors.dim), style: stroke(constants.armWidth))
            }
            if !pose.backLeg.isEmpty {
                context.stroke(polyline([pose.hip] + pose.backLeg), with: .color(BrandColors.text), style: stroke(constants.bodyWidth))
            }
            context.stroke(polyline([pose.hip, pose.knee, pose.ankle, pose.toe]), with: .color(BrandColors.text), style: stroke(constants.bodyWidth))
            context.stroke(polyline([pose.neck, pose.hip]), with: .color(BrandColors.text), style: stroke(constants.bodyWidth))
            context.fill(circle(pose.head, radius: constants.headRadius), with: .color(BrandColors.text))
            context.stroke(polyline([pose.shoulder, pose.elbow, pose.hand]), with: .color(BrandColors.dim), style: stroke(constants.armWidth))
            if let weight = pose.weight {
                context.fill(circle(weight, radius: constants.weightRadius), with: .color(BrandColors.strength))
            }
        }
    }

    private func polyline(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        return path
    }

    private func circle(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    private func stroke(_ width: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}
