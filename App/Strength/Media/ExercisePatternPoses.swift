import CoreGraphics
import Insights

enum ExercisePatternPoses {
    static func poses(_ pattern: MovementPattern) -> (start: FigurePose, end: FigurePose) {
        switch pattern {
        case .squat:
            (
                start: FigurePose(
                    head: CGPoint(x: 61, y: 21),
                    neck: CGPoint(x: 60, y: 32),
                    hip: CGPoint(x: 60, y: 74),
                    knee: CGPoint(x: 62, y: 101),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 60, y: 38),
                    elbow: CGPoint(x: 67, y: 52),
                    hand: CGPoint(x: 71, y: 45),
                    weight: CGPoint(x: 76, y: 46)
                ),
                end: FigurePose(
                    head: CGPoint(x: 56, y: 45),
                    neck: CGPoint(x: 52, y: 56),
                    hip: CGPoint(x: 42, y: 96),
                    knee: CGPoint(x: 70, y: 98),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 53, y: 62),
                    elbow: CGPoint(x: 61, y: 74),
                    hand: CGPoint(x: 67, y: 67),
                    weight: CGPoint(x: 72, y: 68)
                )
            )
        case .hinge:
            (
                start: FigurePose(
                    head: CGPoint(x: 61, y: 21),
                    neck: CGPoint(x: 60, y: 32),
                    hip: CGPoint(x: 60, y: 74),
                    knee: CGPoint(x: 62, y: 101),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 60, y: 38),
                    elbow: CGPoint(x: 62, y: 58),
                    hand: CGPoint(x: 63, y: 76)
                ),
                end: FigurePose(
                    head: CGPoint(x: 102, y: 62),
                    neck: CGPoint(x: 92, y: 66),
                    hip: CGPoint(x: 58, y: 78),
                    knee: CGPoint(x: 60, y: 103),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 88, y: 68),
                    elbow: CGPoint(x: 90, y: 86),
                    hand: CGPoint(x: 90, y: 100)
                )
            )
        case .singleLeg:
            (
                start: FigurePose(
                    head: CGPoint(x: 58, y: 23),
                    neck: CGPoint(x: 57, y: 34),
                    hip: CGPoint(x: 56, y: 76),
                    knee: CGPoint(x: 65, y: 102),
                    ankle: CGPoint(x: 72, y: 128),
                    toe: CGPoint(x: 84, y: 128),
                    shoulder: CGPoint(x: 57, y: 40),
                    elbow: CGPoint(x: 46, y: 56),
                    hand: CGPoint(x: 55, y: 70),
                    backLeg: [CGPoint(x: 42, y: 99), CGPoint(x: 30, y: 120), CGPoint(x: 40, y: 128)]
                ),
                end: FigurePose(
                    head: CGPoint(x: 56, y: 45),
                    neck: CGPoint(x: 55, y: 56),
                    hip: CGPoint(x: 54, y: 98),
                    knee: CGPoint(x: 78, y: 104),
                    ankle: CGPoint(x: 72, y: 128),
                    toe: CGPoint(x: 84, y: 128),
                    shoulder: CGPoint(x: 55, y: 62),
                    elbow: CGPoint(x: 44, y: 78),
                    hand: CGPoint(x: 53, y: 92),
                    backLeg: [CGPoint(x: 50, y: 124), CGPoint(x: 30, y: 120), CGPoint(x: 40, y: 128)]
                )
            )
        case .calf:
            (
                start: FigurePose(
                    head: CGPoint(x: 67, y: 26),
                    neck: CGPoint(x: 64, y: 37),
                    hip: CGPoint(x: 58, y: 78),
                    knee: CGPoint(x: 64, y: 103),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 64, y: 43),
                    elbow: CGPoint(x: 78, y: 54),
                    hand: CGPoint(x: 92, y: 48)
                ),
                end: FigurePose(
                    head: CGPoint(x: 69, y: 20),
                    neck: CGPoint(x: 66, y: 31),
                    hip: CGPoint(x: 60, y: 72),
                    knee: CGPoint(x: 66, y: 97),
                    ankle: CGPoint(x: 63, y: 122),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 66, y: 37),
                    elbow: CGPoint(x: 80, y: 46),
                    hand: CGPoint(x: 92, y: 48)
                )
            )
        case .hipStability:
            (
                start: FigurePose(
                    head: CGPoint(x: -5, y: 120),
                    neck: CGPoint(x: 6, y: 122),
                    hip: CGPoint(x: 48, y: 120),
                    knee: CGPoint(x: 72, y: 104),
                    ankle: CGPoint(x: 88, y: 126),
                    toe: CGPoint(x: 100, y: 128),
                    shoulder: CGPoint(x: 12, y: 122),
                    elbow: CGPoint(x: 30, y: 124),
                    hand: CGPoint(x: 48, y: 125)
                ),
                end: FigurePose(
                    head: CGPoint(x: -3, y: 120),
                    neck: CGPoint(x: 8, y: 120),
                    hip: CGPoint(x: 46, y: 100),
                    knee: CGPoint(x: 72, y: 104),
                    ankle: CGPoint(x: 88, y: 126),
                    toe: CGPoint(x: 100, y: 128),
                    shoulder: CGPoint(x: 13, y: 117),
                    elbow: CGPoint(x: 30, y: 124),
                    hand: CGPoint(x: 48, y: 125)
                )
            )
        case .plyo:
            (
                start: FigurePose(
                    head: CGPoint(x: 56, y: 45),
                    neck: CGPoint(x: 52, y: 56),
                    hip: CGPoint(x: 42, y: 96),
                    knee: CGPoint(x: 70, y: 98),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 53, y: 62),
                    elbow: CGPoint(x: 42, y: 74),
                    hand: CGPoint(x: 32, y: 82)
                ),
                end: FigurePose(
                    head: CGPoint(x: 66, y: 27),
                    neck: CGPoint(x: 64, y: 37),
                    hip: CGPoint(x: 60, y: 79),
                    knee: CGPoint(x: 82, y: 91),
                    ankle: CGPoint(x: 70, y: 113),
                    toe: CGPoint(x: 82, y: 115),
                    shoulder: CGPoint(x: 63, y: 43),
                    elbow: CGPoint(x: 76, y: 32),
                    hand: CGPoint(x: 88, y: 24)
                )
            )
        case .horizontalPush:
            (
                start: FigurePose(
                    head: CGPoint(x: 100, y: 85),
                    neck: CGPoint(x: 89, y: 89),
                    hip: CGPoint(x: 49, y: 102),
                    knee: CGPoint(x: 24, y: 110),
                    ankle: CGPoint(x: -2, y: 118),
                    toe: CGPoint(x: 4, y: 128),
                    shoulder: CGPoint(x: 84, y: 91),
                    elbow: CGPoint(x: 84, y: 110),
                    hand: CGPoint(x: 84, y: 128)
                ),
                end: FigurePose(
                    head: CGPoint(x: 104, y: 109),
                    neck: CGPoint(x: 94, y: 110),
                    hip: CGPoint(x: 52, y: 113),
                    knee: CGPoint(x: 25, y: 116),
                    ankle: CGPoint(x: -2, y: 118),
                    toe: CGPoint(x: 4, y: 128),
                    shoulder: CGPoint(x: 88, y: 110),
                    elbow: CGPoint(x: 74, y: 107),
                    hand: CGPoint(x: 84, y: 128)
                )
            )
        case .horizontalPull:
            (
                start: FigurePose(
                    head: CGPoint(x: 105, y: 64),
                    neck: CGPoint(x: 95, y: 68),
                    hip: CGPoint(x: 56, y: 80),
                    knee: CGPoint(x: 64, y: 104),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 90, y: 70),
                    elbow: CGPoint(x: 90, y: 88),
                    hand: CGPoint(x: 90, y: 106),
                    weight: CGPoint(x: 90, y: 109)
                ),
                end: FigurePose(
                    head: CGPoint(x: 105, y: 64),
                    neck: CGPoint(x: 95, y: 68),
                    hip: CGPoint(x: 56, y: 80),
                    knee: CGPoint(x: 64, y: 104),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 90, y: 70),
                    elbow: CGPoint(x: 74, y: 66),
                    hand: CGPoint(x: 78, y: 84),
                    weight: CGPoint(x: 78, y: 87)
                )
            )
        case .verticalPush:
            (
                start: FigurePose(
                    head: CGPoint(x: 55, y: 47),
                    neck: CGPoint(x: 54, y: 58),
                    hip: CGPoint(x: 54, y: 100),
                    knee: CGPoint(x: 80, y: 100),
                    ankle: CGPoint(x: 80, y: 128),
                    toe: CGPoint(x: 92, y: 128),
                    shoulder: CGPoint(x: 54, y: 64),
                    elbow: CGPoint(x: 64, y: 78),
                    hand: CGPoint(x: 68, y: 64),
                    weight: CGPoint(x: 68, y: 61)
                ),
                end: FigurePose(
                    head: CGPoint(x: 55, y: 47),
                    neck: CGPoint(x: 54, y: 58),
                    hip: CGPoint(x: 54, y: 100),
                    knee: CGPoint(x: 80, y: 100),
                    ankle: CGPoint(x: 80, y: 128),
                    toe: CGPoint(x: 92, y: 128),
                    shoulder: CGPoint(x: 54, y: 64),
                    elbow: CGPoint(x: 64, y: 46),
                    hand: CGPoint(x: 70, y: 28),
                    weight: CGPoint(x: 70, y: 25)
                )
            )
        case .verticalPull:
            (
                start: FigurePose(
                    head: CGPoint(x: 54, y: 56),
                    neck: CGPoint(x: 62, y: 64),
                    hip: CGPoint(x: 60, y: 106),
                    knee: CGPoint(x: 66, y: 128),
                    ankle: CGPoint(x: 46, y: 122),
                    toe: CGPoint(x: 40, y: 130),
                    shoulder: CGPoint(x: 64, y: 70),
                    elbow: CGPoint(x: 67, y: 52),
                    hand: CGPoint(x: 70, y: 34)
                ),
                end: FigurePose(
                    head: CGPoint(x: 62, y: 24),
                    neck: CGPoint(x: 61, y: 36),
                    hip: CGPoint(x: 59, y: 78),
                    knee: CGPoint(x: 65, y: 100),
                    ankle: CGPoint(x: 45, y: 94),
                    toe: CGPoint(x: 39, y: 102),
                    shoulder: CGPoint(x: 61, y: 42),
                    elbow: CGPoint(x: 72, y: 54),
                    hand: CGPoint(x: 70, y: 34)
                )
            )
        case .antiExtension:
            (
                start: FigurePose(
                    head: CGPoint(x: 104, y: 102),
                    neck: CGPoint(x: 93, y: 104),
                    hip: CGPoint(x: 51, y: 110),
                    knee: CGPoint(x: 25, y: 114),
                    ankle: CGPoint(x: -2, y: 118),
                    toe: CGPoint(x: 4, y: 128),
                    shoulder: CGPoint(x: 87, y: 105),
                    elbow: CGPoint(x: 87, y: 125),
                    hand: CGPoint(x: 105, y: 125)
                ),
                end: FigurePose(
                    head: CGPoint(x: 104, y: 100),
                    neck: CGPoint(x: 93, y: 103),
                    hip: CGPoint(x: 51, y: 107),
                    knee: CGPoint(x: 24, y: 112),
                    ankle: CGPoint(x: -2, y: 118),
                    toe: CGPoint(x: 4, y: 128),
                    shoulder: CGPoint(x: 87, y: 104),
                    elbow: CGPoint(x: 87, y: 125),
                    hand: CGPoint(x: 105, y: 125)
                )
            )
        case .antiRotation:
            (
                start: FigurePose(
                    head: CGPoint(x: 61, y: 23),
                    neck: CGPoint(x: 60, y: 34),
                    hip: CGPoint(x: 58, y: 76),
                    knee: CGPoint(x: 64, y: 102),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 60, y: 40),
                    elbow: CGPoint(x: 62, y: 56),
                    hand: CGPoint(x: 72, y: 50),
                    weight: CGPoint(x: 75, y: 50)
                ),
                end: FigurePose(
                    head: CGPoint(x: 61, y: 23),
                    neck: CGPoint(x: 60, y: 34),
                    hip: CGPoint(x: 58, y: 76),
                    knee: CGPoint(x: 64, y: 102),
                    ankle: CGPoint(x: 60, y: 128),
                    toe: CGPoint(x: 72, y: 128),
                    shoulder: CGPoint(x: 60, y: 40),
                    elbow: CGPoint(x: 78, y: 46),
                    hand: CGPoint(x: 96, y: 46),
                    weight: CGPoint(x: 99, y: 46)
                )
            )
        case .lateralCore:
            (
                start: FigurePose(
                    head: CGPoint(x: 100, y: 96),
                    neck: CGPoint(x: 89, y: 100),
                    hip: CGPoint(x: 50, y: 118),
                    knee: CGPoint(x: 25, y: 121),
                    ankle: CGPoint(x: 0, y: 122),
                    toe: CGPoint(x: 10, y: 128),
                    shoulder: CGPoint(x: 84, y: 102),
                    elbow: CGPoint(x: 84, y: 84),
                    hand: CGPoint(x: 84, y: 66),
                    backArm: [CGPoint(x: 84, y: 102), CGPoint(x: 84, y: 124), CGPoint(x: 100, y: 124)]
                ),
                end: FigurePose(
                    head: CGPoint(x: 100, y: 96),
                    neck: CGPoint(x: 89, y: 100),
                    hip: CGPoint(x: 48, y: 110),
                    knee: CGPoint(x: 24, y: 113),
                    ankle: CGPoint(x: 0, y: 122),
                    toe: CGPoint(x: 10, y: 128),
                    shoulder: CGPoint(x: 84, y: 102),
                    elbow: CGPoint(x: 84, y: 84),
                    hand: CGPoint(x: 84, y: 66),
                    backArm: [CGPoint(x: 84, y: 102), CGPoint(x: 84, y: 124), CGPoint(x: 100, y: 124)]
                )
            )
        case .mobilityHip:
            (
                start: FigurePose(
                    head: CGPoint(x: 61, y: 21),
                    neck: CGPoint(x: 60, y: 32),
                    hip: CGPoint(x: 60, y: 74),
                    knee: CGPoint(x: 49, y: 98),
                    ankle: CGPoint(x: 38, y: 121),
                    toe: CGPoint(x: 46, y: 127),
                    shoulder: CGPoint(x: 60, y: 38),
                    elbow: CGPoint(x: 70, y: 54),
                    hand: CGPoint(x: 62, y: 70),
                    backLeg: [CGPoint(x: 61, y: 101), CGPoint(x: 60, y: 128), CGPoint(x: 72, y: 128)]
                ),
                end: FigurePose(
                    head: CGPoint(x: 61, y: 21),
                    neck: CGPoint(x: 60, y: 32),
                    hip: CGPoint(x: 60, y: 74),
                    knee: CGPoint(x: 80, y: 92),
                    ankle: CGPoint(x: 98, y: 110),
                    toe: CGPoint(x: 108, y: 106),
                    shoulder: CGPoint(x: 60, y: 38),
                    elbow: CGPoint(x: 70, y: 54),
                    hand: CGPoint(x: 62, y: 70),
                    backLeg: [CGPoint(x: 61, y: 101), CGPoint(x: 60, y: 128), CGPoint(x: 72, y: 128)]
                )
            )
        case .mobilityAnkle:
            (
                start: FigurePose(
                    head: CGPoint(x: 48, y: 45),
                    neck: CGPoint(x: 47, y: 56),
                    hip: CGPoint(x: 46, y: 98),
                    knee: CGPoint(x: 76, y: 100),
                    ankle: CGPoint(x: 78, y: 127),
                    toe: CGPoint(x: 90, y: 128),
                    shoulder: CGPoint(x: 47, y: 62),
                    elbow: CGPoint(x: 60, y: 78),
                    hand: CGPoint(x: 74, y: 96),
                    backLeg: [CGPoint(x: 44, y: 124), CGPoint(x: 24, y: 124), CGPoint(x: 20, y: 128)]
                ),
                end: FigurePose(
                    head: CGPoint(x: 62, y: 47),
                    neck: CGPoint(x: 61, y: 58),
                    hip: CGPoint(x: 60, y: 100),
                    knee: CGPoint(x: 88, y: 104),
                    ankle: CGPoint(x: 78, y: 127),
                    toe: CGPoint(x: 90, y: 128),
                    shoulder: CGPoint(x: 61, y: 64),
                    elbow: CGPoint(x: 74, y: 80),
                    hand: CGPoint(x: 86, y: 100),
                    backLeg: [CGPoint(x: 44, y: 124), CGPoint(x: 24, y: 124), CGPoint(x: 20, y: 128)]
                )
            )
        case .mobilityThoracic:
            (
                start: FigurePose(
                    head: CGPoint(x: 92, y: 96),
                    neck: CGPoint(x: 82, y: 94),
                    hip: CGPoint(x: 40, y: 96),
                    knee: CGPoint(x: 40, y: 124),
                    ankle: CGPoint(x: 14, y: 124),
                    toe: CGPoint(x: 8, y: 128),
                    shoulder: CGPoint(x: 76, y: 93),
                    elbow: CGPoint(x: 66, y: 106),
                    hand: CGPoint(x: 50, y: 116),
                    backArm: [CGPoint(x: 76, y: 93), CGPoint(x: 77, y: 110), CGPoint(x: 78, y: 127)]
                ),
                end: FigurePose(
                    head: CGPoint(x: 90, y: 80),
                    neck: CGPoint(x: 81, y: 88),
                    hip: CGPoint(x: 40, y: 96),
                    knee: CGPoint(x: 40, y: 124),
                    ankle: CGPoint(x: 14, y: 124),
                    toe: CGPoint(x: 8, y: 128),
                    shoulder: CGPoint(x: 76, y: 89),
                    elbow: CGPoint(x: 74, y: 72),
                    hand: CGPoint(x: 72, y: 54),
                    backArm: [CGPoint(x: 76, y: 89), CGPoint(x: 77, y: 110), CGPoint(x: 78, y: 127)]
                )
            )
        }
    }

    static func props(_ pattern: MovementPattern) -> [[CGPoint]] {
        switch pattern {
        case .calf: [[CGPoint(x: 96, y: 30), CGPoint(x: 96, y: 128)]]
        case .verticalPush: [[CGPoint(x: 32, y: 106), CGPoint(x: 72, y: 106)], [CGPoint(x: 38, y: 106), CGPoint(x: 38, y: 128)], [CGPoint(x: 66, y: 106), CGPoint(x: 66, y: 128)]]
        case .verticalPull: [[CGPoint(x: 30, y: 34), CGPoint(x: 110, y: 34)]]
        case .mobilityAnkle: [[CGPoint(x: 104, y: 60), CGPoint(x: 104, y: 128)]]
        default: []
        }
    }

    static func showsGround(_ pattern: MovementPattern) -> Bool {
        pattern != .verticalPull
    }

    static func pose(_ pattern: MovementPattern, progress: Double) -> FigurePose {
        let (start, end) = poses(pattern)
        return start.interpolated(to: end, progress: CGFloat(min(max(progress, 0), 1)))
    }
}
