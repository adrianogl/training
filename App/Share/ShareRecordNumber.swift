import SwiftUI

struct ShareRecordNumber: View {
    let value: String
    let size: CGFloat
    let color: Color
    let isRecord: Bool

    var body: some View {
        HStack(alignment: .top, spacing: size * ShareConstants.recordMarkGap) {
            Text(value)
                .font(BrandFonts.number(size))
                .foregroundStyle(isRecord ? BrandColors.recordFill : color)
            if isRecord {
                Text(ShareConstants.recordMark)
                    .font(.system(size: max(ShareConstants.recordMarkMinimum, size * ShareConstants.recordMarkScale), weight: .bold))
                    .foregroundStyle(BrandColors.recordFill)
            }
        }
    }
}
