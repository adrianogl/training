import SwiftUI

struct StrengthPlanSegmented<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let name: (Value) -> String
    var isEnabled: (Value) -> Bool = { _ in true }

    var body: some View {
        HStack(spacing: StrengthPlanUIConstants.segmentPadding) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { selection = option } label: {
                    Text(name(option))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selected ? BrandColors.text : BrandColors.dim)
                        .frame(maxWidth: .infinity, minHeight: StrengthPlanUIConstants.segmentHeight)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: StrengthPlanUIConstants.segmentRadius, style: .continuous).fill(BrandColors.track)
                            }
                        }
                        .frame(minHeight: StrengthPlanUIConstants.hitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled(option))
                .opacity(isEnabled(option) ? 1 : DSButtonConstants.disabledOpacity)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, StrengthPlanUIConstants.segmentPadding)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: StrengthPlanUIConstants.innerRadius, style: .continuous))
    }
}

struct StrengthPlanField<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: DSSpacing.s2) {
            Text(label).font(.subheadline).foregroundStyle(BrandColors.text)
            Spacer(minLength: DSSpacing.s2)
            trailing
        }
        .padding(.horizontal, StrengthPlanUIConstants.fieldPadding)
        .frame(minHeight: StrengthPlanUIConstants.rowMinHeight)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: StrengthPlanUIConstants.innerRadius, style: .continuous))
    }
}

struct StrengthPlanCardHeader: View {
    let left: String
    let right: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            DSCardLabel(left)
            Spacer(minLength: DSSpacing.s2)
            Text(right).font(.footnote.weight(.medium)).foregroundStyle(BrandColors.dim)
        }
    }
}

struct StrengthPlanMeter: View {
    let share: Double

    var body: some View {
        DSProgressBar(value: share, color: BrandColors.text.opacity(StrengthPlanUIConstants.meterOpacity), height: StrengthPlanUIConstants.meterHeight)
    }
}
