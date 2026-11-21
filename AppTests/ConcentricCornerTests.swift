import CoreGraphics
import Testing
@testable import trAIning

@Suite struct ConcentricCornerTests {
    @Test func innerRadiusIsCardRadiusMinusPadding() {
        let inner: CGFloat = DSRadius.card - BrandConstants.cardPadding
        #expect(inner == DSRadius.medium)
    }

    @Test func brandCardUsesTheDesignSystemToken() {
        #expect(BrandConstants.cardCornerRadius == DSRadius.card)
        #expect(DSRadius.card == 26)
    }

    @Test func buttonsAndNoticesInsideCardsAreConcentric() {
        #expect(DSRadius.control == DSRadius.medium)
        #expect(ShareConstants.buttonCornerRadius == DSRadius.control)
    }

    @Test func strengthScreensUseTheTokens() {
        #expect(ExerciseDetailConstants.mediaCorner == DSRadius.card)
        #expect(StrengthPlanUIConstants.innerRadius == DSRadius.medium)
        let segment: CGFloat = StrengthPlanUIConstants.innerRadius - StrengthPlanUIConstants.segmentPadding
        #expect(segment == StrengthPlanUIConstants.segmentRadius)
    }
}
