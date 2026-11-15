import SwiftUI

struct WeeklyDaysRow: View {
    let days: [WeeklyDay]
    let compact: Bool

    private typealias C = WeeklyReportConstants

    var body: some View {
        let scale = days.map { max($0.plannedKm ?? 0, $0.doneKm ?? 0) }.max() ?? 0
        HStack(spacing: 6) {
            ForEach(days) { day in
                column(day, scale: scale)
            }
        }
    }

    private func column(_ day: WeeklyDay, scale: Double) -> some View {
        VStack(spacing: 4) {
            Text(compact ? String(day.weekday.prefix(1)) : day.weekday).font(.caption2).foregroundStyle(BrandColors.dim)
            bars(day, scale: scale).frame(height: C.columnHeight)
            Text(day.doneKm.map { TodayText.decimal($0, fractionDigits: compact ? 0 : 1) } ?? "—")
                .font(BrandFonts.number(12))
                .foregroundStyle(BrandColors.text)
            if !compact {
                Text(day.label ?? " ").font(.system(size: 10.5)).foregroundStyle(BrandColors.dim).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.top, 7)
        .padding(.bottom, 8)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(day.state == .off ? C.offOpacity : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility(day))
    }

    private func bars(_ day: WeeklyDay, scale: Double) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width * C.columnBarRatio
            ZStack(alignment: .bottom) {
                if let planned = day.plannedKm, scale > 0 {
                    UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 5)
                        .strokeBorder(Color.primary.opacity(C.dashedOpacity), style: StrokeStyle(lineWidth: 1.5, dash: TodayConstants.calendarDash))
                        .frame(width: width, height: proxy.size.height * planned / scale)
                }
                if let done = day.doneKm, scale > 0 {
                    UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 5)
                        .fill(day.state == .partial ? BrandColors.attention : BrandColors.accentFill)
                        .frame(width: width, height: proxy.size.height * done / scale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func accessibility(_ day: WeeklyDay) -> String {
        var parts = [day.weekday]
        if let label = day.label { parts.append(label) }
        if let planned = day.plannedKm { parts.append("planejado \(TodayText.decimal(planned, fractionDigits: 1)) km") }
        switch day.state {
        case .missed: parts.append("não feito")
        case .pending: parts.append("a fazer")
        default: if let done = day.doneKm { parts.append("feito \(TodayText.decimal(done, fractionDigits: 1)) km") }
        }
        return parts.joined(separator: ", ")
    }
}
