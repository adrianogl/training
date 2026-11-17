import SwiftUI

struct BlockBarView: View {
    let bar: BlockBar?
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(BrandColors.track)
                    .frame(height: WorkoutDetailConstants.barHeight)
                if let band = bar?.band {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(BrandColors.band, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: max(6, width * (band.upperBound - band.lowerBound)), height: WorkoutDetailConstants.bandHeight)
                        .offset(x: width * band.lowerBound)
                }
                if let flat = bar?.flat, let actual = bar?.actual {
                    let from = min(flat.lowerBound, actual.lowerBound)
                    let to = max(flat.upperBound, actual.upperBound)
                    Rectangle()
                        .fill(BrandColors.text.opacity(0.35))
                        .frame(width: width * (to - from), height: 2)
                        .offset(x: width * from)
                }
                if let actual = bar?.actual {
                    Capsule()
                        .fill(color)
                        .frame(width: width * (actual.upperBound - actual.lowerBound), height: WorkoutDetailConstants.barHeight)
                        .offset(x: width * actual.lowerBound)
                }
                if let flat = bar?.flat {
                    Capsule()
                        .strokeBorder(BrandColors.text, lineWidth: 1.5)
                        .frame(width: width * (flat.upperBound - flat.lowerBound), height: WorkoutDetailConstants.bandHeight - 2)
                        .offset(x: width * flat.lowerBound)
                }
            }
            .frame(height: proxy.size.height)
        }
        .frame(height: WorkoutDetailConstants.bandHeight)
        .accessibilityHidden(true)
    }
}
