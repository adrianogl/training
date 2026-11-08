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
                if let actual = bar?.actual {
                    Capsule()
                        .fill(color)
                        .frame(width: width * (actual.upperBound - actual.lowerBound), height: WorkoutDetailConstants.barHeight)
                        .offset(x: width * actual.lowerBound)
                }
            }
            .frame(height: proxy.size.height)
        }
        .frame(height: WorkoutDetailConstants.bandHeight)
        .accessibilityHidden(true)
    }
}
