import Foundation
import Insights
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct ExercisePatternFigureSnapshotTests {
    @Test func every_pattern_has_distinct_start_and_end() {
        #expect(MovementPattern.allCases.count == 16)
        for pattern in MovementPattern.allCases {
            let poses = ExercisePatternPoses.poses(pattern)
            #expect(poses.start != poses.end, "\(pattern)")
        }
    }

    @Test func every_pose_fits_inside_frame_with_margin() {
        let constants = ExercisePatternFigureConstants.self
        let frame = CGRect(origin: .zero, size: constants.viewBox).insetBy(dx: constants.frameMargin, dy: constants.frameMargin)
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: constants.figureOffset.x + point.x * constants.figureScale, y: constants.figureOffset.y + point.y * constants.figureScale)
        }
        func circle(_ center: CGPoint, _ radius: CGFloat) -> [CGPoint] {
            [CGPoint(x: center.x - radius, y: center.y - radius), CGPoint(x: center.x + radius, y: center.y + radius)]
        }
        for pattern in MovementPattern.allCases {
            let fixed = ExercisePatternPoses.props(pattern).flatMap { $0 } + (ExercisePatternPoses.showsGround(pattern) ? constants.ground : [])
            for progress in [0, 0.5, 1.0] {
                let pose = ExercisePatternPoses.pose(pattern, progress: progress)
                var points = [pose.neck, pose.hip, pose.knee, pose.ankle, pose.toe, pose.shoulder, pose.elbow, pose.hand]
                points += pose.backLeg + pose.backArm + fixed + circle(pose.head, constants.headRadius)
                if let weight = pose.weight { points += circle(weight, constants.weightRadius) }
                for point in points.map(place) {
                    #expect(frame.contains(point), "\(pattern) \(progress) \(point)")
                }
            }
        }
    }

    @Test func pull_up_head_stays_clear_of_bar() {
        let clearance = ExercisePatternFigureConstants.headRadius + ExercisePatternFigureConstants.propWidth / 2
        func distance(_ point: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            let dx = b.x - a.x, dy = b.y - a.y
            let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy)))
            return hypot(point.x - (a.x + t * dx), point.y - (a.y + t * dy))
        }
        let segments = ExercisePatternPoses.props(.verticalPull).flatMap { line in zip(line, line.dropFirst()).map { ($0, $1) } }
        #expect(!segments.isEmpty)
        for step in 0...20 {
            let head = ExercisePatternPoses.pose(.verticalPull, progress: Double(step) / 20).head
            for (a, b) in segments {
                #expect(distance(head, a, b) > clearance, "\(step)")
            }
        }
    }

    @Test func squat_and_hinge_end_poses_match_mock() {
        let squat = ExercisePatternPoses.poses(.squat).end
        #expect(squat.neck == CGPoint(x: 52, y: 56))
        #expect(squat.hip == CGPoint(x: 42, y: 96))
        #expect([squat.knee, squat.ankle, squat.toe] == [CGPoint(x: 70, y: 98), CGPoint(x: 60, y: 128), CGPoint(x: 72, y: 128)])
        #expect([squat.shoulder, squat.elbow, squat.hand] == [CGPoint(x: 53, y: 62), CGPoint(x: 61, y: 74), CGPoint(x: 67, y: 67)])
        #expect(squat.head == CGPoint(x: 56, y: 45))
        #expect(squat.weight == CGPoint(x: 72, y: 68))
        let hinge = ExercisePatternPoses.poses(.hinge).end
        #expect(hinge.neck == CGPoint(x: 92, y: 66))
        #expect(hinge.hip == CGPoint(x: 58, y: 78))
        #expect([hinge.knee, hinge.ankle, hinge.toe] == [CGPoint(x: 60, y: 103), CGPoint(x: 60, y: 128), CGPoint(x: 72, y: 128)])
        #expect([hinge.shoulder, hinge.elbow, hinge.hand] == [CGPoint(x: 88, y: 68), CGPoint(x: 90, y: 86), CGPoint(x: 90, y: 100)])
        #expect(hinge.head == CGPoint(x: 102, y: 62))
        #expect(hinge.weight == nil)
    }

    @Test func progress_interpolates_between_poses() {
        let poses = ExercisePatternPoses.poses(.squat)
        #expect(ExercisePatternPoses.pose(.squat, progress: 0) == poses.start)
        #expect(ExercisePatternPoses.pose(.squat, progress: 1) == poses.end)
        #expect(ExercisePatternPoses.pose(.squat, progress: 0.5).hip == CGPoint(x: 51, y: 85))
    }

    @Test func cycle_descends_and_ascends_in_2_6_seconds() {
        #expect(ExercisePatternMotion.progress(at: 0, reduceMotion: false) == 0)
        #expect(abs(ExercisePatternMotion.progress(at: 1.3, reduceMotion: false) - 1) < 0.0001)
        #expect(abs(ExercisePatternMotion.progress(at: 2.6, reduceMotion: false)) < 0.0001)
        let quarter = ExercisePatternMotion.progress(at: 0.65, reduceMotion: false)
        #expect(abs(quarter - 0.5) < 0.0001)
        #expect(ExercisePatternMotion.progress(at: 0.2, reduceMotion: false) < 0.2 / 1.3)
    }

    @Test func reduce_motion_shows_end_pose() {
        for seconds in [0, 0.4, 1.3, 2.0, 2.6] {
            #expect(ExercisePatternMotion.progress(at: seconds, reduceMotion: true) == 1)
        }
    }

    @Test func figures_render() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let patterns: [MovementPattern] = output == nil ? [.squat, .hinge] : MovementPattern.allCases
        let progresses: [Double] = output == nil ? [1] : [0, 1]
        let schemes: [ColorScheme] = output == nil ? [.dark] : [.light, .dark]
        for pattern in patterns {
            for progress in progresses {
                for scheme in schemes {
                    let view = ExercisePatternFigure(pattern: pattern, progress: progress)
                        .frame(width: 360)
                        .background(BrandColors.card)
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    let image = try #require(renderer.uiImage)
                    #expect(image.size == CGSize(width: 360, height: 240))
                    if let output, let data = image.pngData() {
                        let name = "\(pattern.rawValue)-\(Int(progress))-\(scheme == .dark ? "dark" : "light").png"
                        try data.write(to: output.appending(path: name))
                    }
                }
            }
        }
    }
}
