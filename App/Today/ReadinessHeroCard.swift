import Metrics
import SwiftUI

struct ReadinessHeroCard: View {
    let model: TodayModel
    var overload: OverloadAlert?
    var recovery: RecoveryEstimate?
    @Environment(\.horizontalSizeClass) private var sizeClass

    private typealias C = TodayConstants

    var body: some View {
        NavigationLink(value: TodayRoute.readiness) {
            VStack(alignment: .leading, spacing: 14) {
                if model.summary.readiness != nil && model.summary.readinessFromYesterday {
                    yesterdayBanner
                }
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(C.readinessTitle).padding(.top, 0).padding(.bottom, 0)
                    Spacer()
                    if let recovery, recovery.remainingHours > 0 {
                        Text(String(format: RecoveryConstants.headerFormat, recovery.remainingHours))
                            .font(.caption)
                            .foregroundStyle(BrandColors.dim)
                    }
                }
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
                } else if let score = model.fallbackScore {
                    HStack(alignment: .center, spacing: 18) {
                        ScoreGauge(score: score, size: sizeClass == .regular ? C.heroGaugeSize : C.compactGaugeSize)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(C.verdictPhrases[readinessVerdict(score: score)] ?? "")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(BrandColors.text)
                            Text(C.garminReadinessNote)
                                .font(.subheadline)
                                .foregroundStyle(BrandColors.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
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
                if let overload {
                    ReadinessOverloadLine(alert: overload)
                }
                if let recovery {
                    ReadinessRecoveryStrip(estimate: recovery)
                }
            }
            .brandCard(fillsHeight: true)
        }
        .buttonStyle(.plain)
    }

    private var yesterdayBanner: some View {
        let radius = BrandConstants.cardCornerRadius
        return Text(C.readinessFromYesterday)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(BrandColors.attention)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BrandConstants.cardPadding)
            .padding(.vertical, C.yesterdayBannerPadding)
            .background(
                BrandColors.attention.opacity(C.yesterdayBannerOpacity),
                in: UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .continuous)
            )
            .padding(.horizontal, -BrandConstants.cardPadding)
            .padding(.top, -BrandConstants.cardPadding)
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

private struct ReadinessOverloadLine: View {
    let alert: OverloadAlert

    var body: some View {
        let detail = OverloadText.flaggedLine(alert)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(BrandColors.attention)
            VStack(alignment: .leading, spacing: 2) {
                Text(OverloadText.headline(alert))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrandColors.attention)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(BrandColors.text)
                }
                Text(OverloadConstants.advice).font(.caption).foregroundStyle(BrandColors.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(BrandColors.attention.opacity(TodayConstants.overloadTintOpacity), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ReadinessRecoveryStrip: View {
    let estimate: RecoveryEstimate

    private typealias C = RecoveryConstants

    var body: some View {
        let ready = estimate.remainingHours <= 0
        VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(BrandColors.line)
            HStack(alignment: .firstTextBaseline) {
                if ready {
                    Text(C.readyNowLine).foregroundStyle(BrandColors.accent)
                } else {
                    Text(String(format: C.readyLineFormat, RecoveryText.dayHour(estimate.readyAt))).foregroundStyle(BrandColors.text)
                }
                Spacer()
                if !ready {
                    Text("\(String(format: C.hoursRemainingFormat, estimate.remainingHours)) \(C.hoursRemainingUnit)")
                        .foregroundStyle(BrandColors.dim)
                }
            }
            .font(.footnote.weight(.semibold))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BrandColors.track)
                    Capsule()
                        .fill(ready ? BrandColors.accentFill : BrandColors.attention)
                        .frame(width: max(proxy.size.width * estimate.progress, C.stripHeight))
                }
            }
            .frame(height: C.stripHeight)
            if let next = estimate.upcoming.first {
                Text(RecoveryText.nextLine(next)).font(.caption).foregroundStyle(BrandColors.dim)
            }
            if let advice = estimate.advice {
                Text(advice).font(.caption).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
