import CoreGraphics

struct FigurePose: Equatable {
    var head, neck, hip, knee, ankle, toe, shoulder, elbow, hand: CGPoint
    var weight: CGPoint?
    var backLeg: [CGPoint] = []
    var backArm: [CGPoint] = []

    func interpolated(to end: FigurePose, progress: CGFloat) -> FigurePose {
        func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * progress, y: a.y + (b.y - a.y) * progress)
        }
        func mix(_ a: [CGPoint], _ b: [CGPoint]) -> [CGPoint] {
            a.count == b.count ? zip(a, b).map { mix($0, $1) } : a
        }
        return FigurePose(
            head: mix(head, end.head),
            neck: mix(neck, end.neck),
            hip: mix(hip, end.hip),
            knee: mix(knee, end.knee),
            ankle: mix(ankle, end.ankle),
            toe: mix(toe, end.toe),
            shoulder: mix(shoulder, end.shoulder),
            elbow: mix(elbow, end.elbow),
            hand: mix(hand, end.hand),
            weight: weight.flatMap { start in end.weight.map { mix(start, $0) } },
            backLeg: mix(backLeg, end.backLeg),
            backArm: mix(backArm, end.backArm)
        )
    }
}
