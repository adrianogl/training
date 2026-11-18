import SwiftUI

struct OverloadCard: View {
    let alert: OverloadAlert

    private typealias C = OverloadConstants

    var body: some View {
        DSNotice(tone: .attention, title: C.title, text: String(format: C.summaryFormat, alert.days)) {
            VStack(alignment: .leading, spacing: DSSpacing.s1) {
                if let now = alert.restingNow, let base = alert.restingBase {
                    row(C.resting, String(format: C.baseFormat, base), "\(now)", flagged: alert.restingHigh)
                }
                if let now = alert.hrvNow, let base = alert.hrvBase {
                    row(C.hrv, String(format: C.baseHrvFormat, base), "\(now)", flagged: alert.hrvLow)
                }
                if let ratio = alert.ratio {
                    row(C.load, C.loadRange, TodayText.decimal(ratio, fractionDigits: 1), flagged: alert.loadHigh)
                }
                Text(C.advice).font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
    }

    private func row(_ label: String, _ base: String, _ value: String, flagged: Bool) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(BrandColors.text)
            Spacer()
            Text(base).font(BrandFonts.number(13)).foregroundStyle(BrandColors.dim)
            Text(value).font(BrandFonts.number(15)).foregroundStyle(flagged ? BrandColors.rest : BrandColors.text)
                .frame(minWidth: 40, alignment: .trailing)
        }
    }
}
