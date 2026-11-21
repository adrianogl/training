import SwiftUI

struct RecordCard: ViewModifier {
    let isRecord: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: BrandConstants.cardCornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content.overlay {
            if isRecord {
                LinearGradient(colors: [BrandColors.recordGlow, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: ScoreConstants.perfectGlowHeight))
                    .clipShape(shape)
                    .allowsHitTesting(false)
                shape.strokeBorder(BrandColors.recordFill.opacity(RecordCardConstants.borderOpacity), lineWidth: ScoreConstants.perfectBorderWidth)
            }
        }
    }
}

extension View {
    func recordCard(_ isRecord: Bool) -> some View {
        modifier(RecordCard(isRecord: isRecord))
    }
}
