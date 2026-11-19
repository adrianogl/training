import SwiftUI

enum ReadinessFactorScale {
    static func of(_ rows: [ReadinessFactorRowData]) -> Double {
        max(rows.compactMap { $0.points.map(abs) }.max() ?? 0, TodayConstants.driverScaleMinimum)
    }

    static func color(_ points: Double?) -> Color {
        guard let points else { return BrandColors.dim }
        return points >= 0 ? BrandColors.readyFill : BrandColors.attention
    }
}

struct ReadinessFactorBar: View {
    let points: Double?
    let scale: Double

    var body: some View {
        GeometryReader { proxy in
            let half = proxy.size.width / 2
            let length = min(abs(points ?? 0) / scale, 1) * half
            let isUp = (points ?? 0) >= 0
            ZStack(alignment: .leading) {
                Capsule().fill(BrandColors.track)
                Rectangle()
                    .fill(BrandColors.line)
                    .frame(width: 1, height: TodayConstants.driverBarHeight + 6)
                    .offset(x: half)
                Capsule()
                    .fill(ReadinessFactorScale.color(points))
                    .frame(width: length)
                    .offset(x: isUp ? half : half - length)
            }
        }
        .frame(height: TodayConstants.driverBarHeight)
        .accessibilityHidden(true)
    }
}

struct ReadinessFactorLine: View {
    let row: ReadinessFactorRowData
    let scale: Double

    private typealias C = TodayConstants

    var body: some View {
        HStack(spacing: 10) {
            Text(row.name)
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: C.driverNameWidth, alignment: .leading)
            if row.points == nil {
                Text(row.valueText)
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(BrandColors.track).frame(height: C.driverBarHeight + 10))
                Color.clear.frame(width: C.driverValueWidth, height: 1)
            } else {
                ReadinessFactorBar(points: row.points, scale: scale)
                Text(row.valueText)
                    .font(BrandFonts.number(15))
                    .foregroundStyle(BrandColors.text)
                    .frame(width: C.driverValueWidth, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ReadinessFactorAxis: View {
    private typealias C = TodayConstants

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: C.driverNameWidth, height: 1)
            HStack {
                Text(C.driverDown)
                Spacer()
                Text(C.driverUp)
            }
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(BrandColors.dim)
            Color.clear.frame(width: C.driverValueWidth, height: 1)
        }
        .accessibilityHidden(true)
    }
}

struct ReadinessFactorDetail: View {
    let row: ReadinessFactorRowData
    let scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Spacer()
                if row.points == nil {
                    Text(row.valueText).font(.caption).foregroundStyle(BrandColors.dim)
                } else {
                    Text(row.valueText).font(BrandFonts.number(16)).foregroundStyle(ReadinessFactorScale.color(row.points))
                }
            }
            ReadinessFactorBar(points: row.points, scale: scale)
            Text(row.detail)
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
