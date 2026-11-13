import SwiftUI

struct ReadinessHeroCard: View {
    let model: TodayModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = TodayConstants

    var body: some View {
        NavigationLink(value: TodayRoute.readiness) {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(C.readinessTitle).padding(.top, 0).padding(.bottom, 0)
                if let breakdown = model.summary.readiness {
                    HStack(alignment: .center, spacing: 18) {
                        ScoreGauge(score: breakdown.score, size: sizeClass == .regular ? C.heroGaugeSize : C.compactGaugeSize)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.summary.verdict.flatMap { C.verdictPhrases[$0] } ?? "")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(BrandColors.text)
                            if !model.readinessSentence.isEmpty {
                                Text(model.readinessSentence)
                                    .font(.subheadline)
                                    .foregroundStyle(BrandColors.text.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    ReadinessDrivers(rows: model.factorRows)
                } else {
                    Text(C.readinessEmpty)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.dim)
                }
                if let stress = model.summary.supporting.stress {
                    Text(String(format: C.stressContextFormat, stress))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
            }
            .brandCard(fillsHeight: true)
        }
        .buttonStyle(.plain)
    }
}

private struct ReadinessDrivers: View {
    let rows: [ReadinessFactorRowData]

    private typealias C = TodayConstants

    var body: some View {
        let scale = max(rows.compactMap { $0.points.map(abs) }.max() ?? 0, C.driverScaleMinimum)
        VStack(spacing: 8) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Text(row.name)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.dim)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: C.driverNameWidth, alignment: .leading)
                    DriverBar(points: row.points, scale: scale)
                    Text(row.pointsText ?? "—")
                        .font(BrandFonts.number(15))
                        .foregroundStyle(row.points == nil ? BrandColors.dim : BrandColors.text)
                        .frame(width: C.driverValueWidth, alignment: .trailing)
                }
            }
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
        }
    }
}

private struct DriverBar: View {
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
                    .fill(isUp ? BrandColors.accentFill : BrandColors.rest)
                    .frame(width: length)
                    .offset(x: isUp ? half : half - length)
            }
        }
        .frame(height: TodayConstants.driverBarHeight)
    }
}
