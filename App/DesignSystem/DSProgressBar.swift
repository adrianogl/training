import SwiftUI

struct DSProgressBar: View {
    let value: Double
    var color: Color = BrandColors.accentFill
    var height: CGFloat = DSProgressConstants.height
    var marker: Double?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let share = min(max(value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(BrandColors.track)
                Capsule().fill(color).frame(width: share > 0 ? max(width * share, height) : 0)
                if let marker {
                    Rectangle()
                        .fill(BrandColors.text)
                        .frame(width: DSProgressConstants.markerWidth, height: height + DSProgressConstants.markerOverhang)
                        .offset(x: min(width * min(max(marker, 0), 1), width) - DSProgressConstants.markerWidth)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
