import SwiftUI

struct StrengthPlanEndedNotice: View {
    let summary: StrengthPlanEndedSummary

    var body: some View {
        StrengthPlanNoticeBox {
            Text(summary.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
            Text(summary.body).font(.footnote).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StrengthPlanMigrationNotice: View {
    let text: String
    let onAdjust: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        StrengthPlanNoticeBox {
            Text(text).font(.footnote).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: DSSpacing.s5) {
                Button(StrengthPlanText.adjust, action: onAdjust).buttonStyle(.ds(.text))
                Button(StrengthPlanText.ok, action: onDismiss).buttonStyle(.ds(.text))
            }
        }
    }
}

struct StrengthPlanClaudeOffer: View {
    let onAsk: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        StrengthPlanNoticeBox(tint: ClaudeConstants.color) {
            Text(StrengthPlanText.claudeSavedTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
            Text(StrengthPlanText.claudeSavedBody).font(.footnote).foregroundStyle(BrandColors.dim)
            HStack(spacing: DSSpacing.s5) {
                Button(ClaudeText.askButton, action: onAsk).buttonStyle(.ds(.text))
                Button(StrengthPlanText.ok, action: onDismiss).buttonStyle(.ds(.text))
            }
        }
    }
}

struct StrengthPlanNoticeBox<Content: View>: View {
    var tint: Color = BrandColors.attention
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StrengthPlanUIConstants.innerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: DSSpacing.s1) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, StrengthPlanUIConstants.fieldPadding)
        .padding(.vertical, StrengthPlanUIConstants.spacing)
        .background(tint.opacity(DSNoticeConstants.fillOpacity), in: shape)
        .overlay(shape.strokeBorder(tint.opacity(DSNoticeConstants.borderOpacity), lineWidth: 1))
    }
}
