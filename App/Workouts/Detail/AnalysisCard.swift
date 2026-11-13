import SwiftUI

struct AnalysisCard: View {
    let columns: AnalysisColumns
    let onDevice: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = WorkoutDetailConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(C.analysisTitle).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                if onDevice { OnDeviceCaption() }
            }
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    column(C.analysisNegative, BrandColors.rest, columns.negative)
                    Divider().overlay(BrandColors.line)
                    column(C.analysisPositive, BrandColors.accentFill, columns.positive)
                    Divider().overlay(BrandColors.line)
                    column(C.analysisExpected, BrandColors.dim, columns.expected)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    column(C.analysisNegative, BrandColors.rest, columns.negative)
                    column(C.analysisPositive, BrandColors.accentFill, columns.positive)
                    column(C.analysisExpected, BrandColors.dim, columns.expected)
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
                    if let ordinal = item.blockOrdinal {
                        Text(String(format: C.analysisBlockFormat, ordinal))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BrandColors.dim)
                    }
                    Text(item.text)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
