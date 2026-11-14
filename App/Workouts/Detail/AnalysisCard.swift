import SwiftUI

struct AnalysisCard: View {
    let columns: AnalysisColumns
    let onDevice: Bool
    var title = WorkoutDetailConstants.analysisTitle
    var expectedTitle = WorkoutDetailConstants.analysisExpected
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = WorkoutDetailConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                if onDevice { OnDeviceCaption() }
            }
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    column(C.analysisNegative, BrandColors.rest, columns.negative)
                    Divider().overlay(BrandColors.line)
                    column(C.analysisPositive, BrandColors.accentFill, columns.positive)
                    Divider().overlay(BrandColors.line)
                    column(expectedTitle, BrandColors.dim, columns.expected)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    column(C.analysisNegative, BrandColors.rest, columns.negative)
                    column(C.analysisPositive, BrandColors.accentFill, columns.positive)
                    column(expectedTitle, BrandColors.dim, columns.expected)
                }
            }
        }
        .brandCard()
    }

    private func column(_ title: String, _ color: Color, _ items: [AnalysisItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
                Text(title).font(.footnote.weight(.bold)).foregroundStyle(BrandColors.text)
            }
            if items.isEmpty {
                Text(C.analysisNone).font(.subheadline).foregroundStyle(BrandColors.dim)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let evidence = item.evidence {
                        Text(evidence)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BrandColors.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    Text(item.why)
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
