import Insights
import SwiftUI

struct StrengthHomeEquipmentCard: View {
    @State private var chosen = TrainerStrengthPrefsStore().load().effectiveHomeEquipment

    private typealias C = StrengthPlanUIConstants

    var body: some View {
        VStack(alignment: .leading, spacing: C.spacing) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: DSSpacing.s2), GridItem(.flexible(), spacing: DSSpacing.s2)], spacing: DSSpacing.s2) {
                ForEach(StrengthCatalogConstants.homeEquipmentOptions + [.bodyweight], id: \.self) { equipment in
                    item(equipment)
                }
            }
            Text(StrengthPlanText.homeEquipmentHint).font(.footnote).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
        }
        .brandCard()
    }

    private func item(_ equipment: StrengthEquipment) -> some View {
        let fixed = equipment == .bodyweight
        let selected = fixed || chosen.contains(equipment)
        let shape = RoundedRectangle(cornerRadius: C.innerRadius, style: .continuous)
        return Button {
            TrainerStrengthPrefsStore().toggleHomeEquipment(equipment)
            chosen = TrainerStrengthPrefsStore().load().effectiveHomeEquipment
        } label: {
            HStack(spacing: DSSpacing.s2) {
                Image(systemName: selected ? C.checkedSymbol : C.uncheckedSymbol)
                    .foregroundStyle(selected ? BrandColors.accentFill : BrandColors.dim)
                Text(StrengthPlanText.equipmentName(equipment))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DSSpacing.s3)
            .padding(.vertical, DSSpacing.s2)
            .frame(maxHeight: .infinity)
            .frame(minHeight: C.hitSize)
            .background(selected ? BrandColors.accentFill.opacity(C.optionSelectedOpacity) : BrandColors.track, in: shape)
            .overlay(shape.strokeBorder(selected ? BrandColors.accentFill : .clear, lineWidth: C.optionBorder))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(fixed)
        .opacity(fixed ? DSButtonConstants.disabledOpacity : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
