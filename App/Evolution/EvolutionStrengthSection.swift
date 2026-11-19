import SwiftUI

struct EvolutionStrengthGroupsCard: View {
    let model: StrengthModel

    private typealias C = StrengthConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(StrengthText.groupsShortTitle)
                Spacer()
                Text(StrengthText.thisWeek).font(.caption).foregroundStyle(BrandColors.dim)
            }
            let totals = model.weekGroupTotals
            let top = max(totals.first?.sets ?? 1, 1)
            if totals.isEmpty {
                Text(StrengthText.noWeek).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            ForEach(totals.prefix(C.evolutionGroupsLimit)) { total in
                HStack(spacing: 10) {
                    Text(StrengthText.groupName(total.group)).font(.footnote).foregroundStyle(BrandColors.text)
                        .frame(width: 92, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(C.heat[max(min(total.level, C.heat.count), 1) - 1])
                            .frame(width: max(6, proxy.size.width * total.sets / top), height: 8)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 12)
                    Text("\(Int(total.sets.rounded()))").font(BrandFonts.number(14)).foregroundStyle(BrandColors.text)
                        .frame(width: 28, alignment: .trailing)
                }
            }
            NavigationLink {
                StrengthVolumeView(model: model)
            } label: {
                CardLinkFooter(title: StrengthText.groupsLink)
            }
            .buttonStyle(.cardLink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}

struct EvolutionStrengthFrequencyCard: View {
    let model: StrengthModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(StrengthText.perWeekTitle)
                Spacer()
                Text("\(StrengthText.average) \(StrengthText.averageLabel(model.averagePerWeek))").font(.caption).foregroundStyle(BrandColors.dim)
            }
            StrengthFrequencyBars(counts: model.weeklyCounts)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
