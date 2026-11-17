import Insights
import SwiftUI

struct WeeklyStrengthBlock: View {
    let summary: WeeklyStrengthSummary
    var sources: [StrengthSourceTally] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(StrengthText.section).font(.caption.weight(.semibold)).tracking(1).textCase(.uppercase).foregroundStyle(BrandColors.dim)
            HStack(alignment: .firstTextBaseline) {
                Text(StrengthText.reportSessions(summary)).font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
                Spacer()
                Text(StrengthText.reportDetail(summary)).font(.caption).foregroundStyle(BrandColors.dim)
            }
            if sources.count > 1 || sources.contains(where: { $0.source == .trainer }) {
                Text(sources.map { "\(TrainerStrengthText.sourceName($0.source)) \($0.done) de \($0.planned)" }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.strength)
            }
            if !summary.groups.isEmpty {
                let top = max(summary.groups.first?.sets ?? 1, 1)
                VStack(spacing: 6) {
                    ForEach(summary.groups) { total in
                        HStack(spacing: 8) {
                            Text(StrengthText.groupName(total.group)).font(.footnote).foregroundStyle(BrandColors.text).frame(width: 84, alignment: .leading)
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(StrengthConstants.heat[max(min(total.level, StrengthConstants.heat.count), 1) - 1])
                                    .frame(width: max(6, proxy.size.width * total.sets / top), height: 7)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(height: 10)
                            Text("\(Int(total.sets.rounded()))").font(BrandFonts.number(13)).foregroundStyle(BrandColors.text).frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
            ForEach(summary.records, id: \.name) { record in
                HStack(spacing: 8) {
                    StrengthRecordBadge()
                    Text(StrengthText.reportRecord(record)).font(.footnote).foregroundStyle(BrandColors.text)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            ForEach(summary.missed, id: \.self) { missed in
                Text(missed).font(.footnote).foregroundStyle(BrandColors.attention)
            }
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BrandColors.line))
    }
}
