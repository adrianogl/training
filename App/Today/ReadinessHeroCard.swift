import Metrics
import SwiftUI

struct ReadinessHeroCard: View {
    let model: TodayModel
    var overload: OverloadAlert?
    var recovery: RecoveryEstimate?
    var legDay: StrengthLegDay?
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppModel.self) private var app

    private typealias C = TodayConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.summary.readinessMissingNight == true {
                banner(C.readinessMissingNight)
            } else if model.summary.readiness != nil && model.summary.readinessFromYesterday {
                banner(C.readinessFromYesterday)
            } else if app.watchKind == .appleWatch, model.summary.readiness != nil, model.summary.readinessRaw[.hrv] == nil {
                DSNotice(tone: .info, title: C.appleBaselineTitle, text: C.appleBaselineText)
            }
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(C.readinessTitle)
                Spacer()
                if let recovery, recovery.remainingHours > 0 {
                    Text(String(format: RecoveryConstants.headerFormat, recovery.remainingHours))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                }
            }
            if model.summary.readinessMissingNight == true {
                VStack(alignment: .leading, spacing: 6) {
                    Text(C.readinessMissingNightNote)
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    if let score = model.summary.readiness?.score {
                        Text(String(format: C.readinessYesterdayReferenceFormat, score))
                            .font(.caption)
                            .foregroundStyle(BrandColors.dim)
                    }
                }
            } else if let breakdown = model.summary.readiness {
                HStack(alignment: .center, spacing: 18) {
                    ScoreGauge(score: breakdown.score, size: sizeClass == .regular ? C.heroGaugeSize : C.compactGaugeSize)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.summary.verdict.flatMap { C.verdictPhrases[$0] } ?? "")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(BrandColors.text)
                        let sentence = [model.readinessSentence, legDay.map(StrengthText.legSentence)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
                        if !sentence.isEmpty {
                            Text(sentence)
                                .font(.subheadline)
                                .foregroundStyle(BrandColors.text.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                ReadinessDrivers(rows: model.factorRows)
                if let legDay { StrengthLegFactorRow(leg: legDay) }
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
            Spacer(minLength: 0)
            NavigationLink(value: TodayRoute.readiness) { CardLinkFooter(title: CardLinkConstants.details) }
                .buttonStyle(.cardLink)
        }
        .brandCard(fillsHeight: true)
    }

    private func banner(_ text: String) -> some View {
        DSNotice(tone: .attention, text: text)
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
        DSNotice(tone: .attention, title: OverloadText.headline(alert), text: detail.isEmpty ? OverloadConstants.advice : detail + "\n" + OverloadConstants.advice)
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
            DSProgressBar(value: max(estimate.progress, 0.0001), color: ready ? BrandColors.readyFill : BrandColors.attention, height: C.stripHeight)
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
