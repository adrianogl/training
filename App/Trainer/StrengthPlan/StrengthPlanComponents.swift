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

struct StrengthPlanOptionList<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let name: (Value) -> String
    let detail: (Value) -> String

    private typealias C = StrengthPlanUIConstants

    var body: some View {
        VStack(spacing: DSSpacing.s1) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                let shape = RoundedRectangle(cornerRadius: C.innerRadius, style: .continuous)
                Button { selection = option } label: {
                    HStack(alignment: .top, spacing: DSSpacing.s3) {
                        Circle()
                            .strokeBorder(selected ? BrandColors.accentFill : BrandColors.dim, lineWidth: 2)
                            .background(Circle().inset(by: C.optionDotInset).fill(selected ? BrandColors.accentFill : .clear))
                            .frame(width: C.optionDotSize, height: C.optionDotSize)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name(option)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                            Text(detail(option)).font(.footnote).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DSSpacing.s3)
                    .padding(.vertical, DSSpacing.s3)
                    .frame(minHeight: C.hitSize)
                    .background(selected ? BrandColors.accentFill.opacity(C.optionSelectedOpacity) : .clear, in: shape)
                    .overlay(shape.strokeBorder(selected ? BrandColors.accentFill : .clear, lineWidth: C.optionBorder))
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
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
