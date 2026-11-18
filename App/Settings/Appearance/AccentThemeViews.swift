import SwiftUI

struct AccentThemePicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: DSSpacing.s2) {
            ForEach(AccentTheme.allCases) { theme in
                Button { selection = theme.rawValue } label: {
                    AccentThemeCard(theme: theme, isSelected: AccentTheme.stored(selection) == theme)
                }
                .buttonStyle(.cardLink)
                .environment(\.accentTheme, theme)
            }
        }
    }
}

struct AccentThemeCard: View {
    let theme: AccentTheme
    let isSelected: Bool

    private typealias C = AccentThemeConstants

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.card - 2, style: .continuous)
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            (Text(BrandConstants.logoPrefix) + Text(BrandConstants.logoHighlight).foregroundStyle(BrandColors.accent) + Text(BrandConstants.logoSuffix))
                .font(.system(size: 11, weight: .heavy).width(.expanded))
                .tracking(1.5)
                .foregroundStyle(BrandColors.text)
            DSProgressBar(value: C.previewShare)
            DSChip(text: C.sampleChip, tone: .accent, style: .solid)
            Text(C.sampleButton)
                .font(.caption.weight(.bold))
                .foregroundStyle(BrandColors.onAccent)
                .frame(maxWidth: .infinity, minHeight: 26)
                .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(theme.title).font(.subheadline.weight(.bold)).foregroundStyle(BrandColors.text)
                Text(theme.subtitle).font(.caption2).foregroundStyle(BrandColors.dim)
            }
        }
        .padding(DSSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColors.card, in: shape)
        .overlay(shape.strokeBorder(isSelected ? BrandColors.accentFill : BrandColors.cardBorder, lineWidth: isSelected ? 2 : 1))
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(BrandColors.onAccent)
                    .frame(width: 20, height: 20)
                    .background(BrandColors.accentFill, in: Circle())
                    .padding(DSSpacing.s2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct AccentThemePreview: View {
    private typealias C = AccentThemeConstants

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s3) {
            VStack(alignment: .leading, spacing: DSSpacing.s2) {
                DSCardLabel(C.previewReadiness)
                HStack(spacing: DSSpacing.s3) {
                    ScoreGauge(score: C.previewScore, size: 76)
                    Text(C.previewVerdict).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                }
                CardLinkFooter(title: CardLinkConstants.details)
            }
            .brandCard()
            VStack(alignment: .leading, spacing: DSSpacing.s2) {
                HStack {
                    Text(C.previewWeek).font(.subheadline).foregroundStyle(BrandColors.text)
                    Spacer()
                    CardLinkBadge()
                }
                DSProgressBar(value: C.previewShare)
                HStack(spacing: 6) {
                    DSChip(text: C.previewOnPace, tone: .accent)
                    DSChip(text: C.sampleChip, tone: .accent, style: .solid)
                    DSChip(text: C.previewStrength, tone: .strength)
                }
            }
            .brandCard()
            Text(C.previewSend)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(BrandColors.onAccent)
                .frame(maxWidth: .infinity, minHeight: DSButtonConstants.height)
                .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: DSRadius.control, style: .continuous))
        }
        .accessibilityHidden(true)
    }
}
