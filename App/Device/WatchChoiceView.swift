import SwiftUI

struct WatchChoiceView: View {
    let onChoose: (WatchKind) -> Void
    @State private var selection = WatchKind.garmin

    private typealias C = WatchKindConstants

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                Logo(showsTagline: true).padding(.top, 32)
                VStack(alignment: .leading, spacing: 6) {
                    Text(C.choiceTitle).font(BrandFonts.largeTitle).foregroundStyle(BrandColors.text)
                    Text(C.choiceText).foregroundStyle(BrandColors.dim)
                }
                WatchKindPicker(selection: $selection)
                Button(C.continueLabel) { onChoose(selection) }.buttonStyle(.ds(.primary))
                Text(C.choiceFooter).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            .frame(maxWidth: AccountConstants.formMaxWidth)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(BrandBackground())
    }
}

struct WatchKindPicker: View {
    @Binding var selection: WatchKind

    var body: some View {
        VStack(spacing: DSSpacing.s2) {
            ForEach(WatchKind.allCases) { kind in
                Button { selection = kind } label: { option(kind) }.buttonStyle(.cardLink)
            }
        }
    }

    private func option(_ kind: WatchKind) -> some View {
        let isSelected = selection == kind
        let shape = RoundedRectangle(cornerRadius: DSRadius.card - 2, style: .continuous)
        return HStack(spacing: DSSpacing.s3) {
            Image(systemName: kind.symbol)
                .font(.title3)
                .foregroundStyle(BrandColors.text)
                .frame(width: 42, height: 42)
                .background(BrandColors.track, in: RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(kind.title).font(.body.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(kind.detail).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? BrandColors.accentFill : BrandColors.dim)
        }
        .padding(DSSpacing.s3)
        .background(BrandColors.card, in: shape)
        .overlay(shape.strokeBorder(isSelected ? BrandColors.accentFill : BrandColors.cardBorder, lineWidth: isSelected ? 2 : 1))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
