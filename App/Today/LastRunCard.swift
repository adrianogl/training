import Charts
import SwiftUI
import WorkoutAnalysis

struct LastRunCard: View {
    let lastRun: LastRunSummary
    var plannedKm: Double?

    private typealias C = TodayConstants
    private typealias L = LastRunConstants

    var body: some View {
        NavigationLink(value: TodayRoute.workout(lastRun.activityId)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel("\(C.lastRunTitle) · \(lastRun.dateText)").padding(.top, 0).padding(.bottom, 0)
                    Spacer()
                    Text(L.viewAnalysis).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
                titleRow
                if let plannedKm, plannedKm > 0, let km = lastRun.kilometers { planBar(km: km, planned: plannedKm) }
                stats
                if let splits = lastRun.splits, splits.count > 1 { paceChart(splits) }
                if let shares = lastRun.zoneShares, shares.contains(where: { $0 > 0 }) { zones(shares) }
                if let similar = lastRun.similar, !similar.isEmpty { recent(similar) }
                if let reading = lastRun.reading {
                    Text(reading).font(.footnote).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
                } else if let evolution = lastRun.evolution {
                    Text(evolution)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(BrandColors.accentFill.opacity(0.16), in: Capsule())
                    if lastRun.evolutionOnDevice {
                        OnDeviceCaption()
                    }
                } else if lastRun.similar != nil {
                    Text(String(format: L.noSimilarFormat, lastRun.kind.flatMap { L.kindNames[$0] } ?? "")).font(.caption).foregroundStyle(BrandColors.dim)
                } else {
                    Text(C.lastRunNoComparison).font(.caption).foregroundStyle(BrandColors.dim)
                }
                if let notice = lastRun.notice {
                    Text(notice).font(.caption).foregroundStyle(BrandColors.attention)
                }
            }
            .brandCard(fillsHeight: true)
            .perfectScoreCard(score: lastRun.score, activityId: lastRun.activityId)
        }
        .buttonStyle(.plain)
    }

    private var titleRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lastRun.kind.flatMap { L.kindTitles[$0] } ?? lastRun.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(2)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            Spacer()
            if let score = lastRun.score {
                ScoreBadge(value: score, size: ScoreConstants.cardBadgeSize + 8)
            }
        }
    }

    private var subtitle: String? {
        let parts = [lastRun.place, lastRun.durationText].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func planBar(km: Double, planned: Double) -> some View {
        let share = min(km / planned, 1)
        let percent = Int((km / planned * 100).rounded())
        return HStack(spacing: 8) {
            Text(String(format: L.planFormat, TodayText.decimal(planned, fractionDigits: planned.rounded() == planned ? 0 : 1))).font(.caption).foregroundStyle(BrandColors.dim)
            GeometryReader { proxy in
                Capsule().fill(BrandColors.track)
                    .overlay(alignment: .leading) {
                        Capsule().fill(km / planned >= L.planGood ? BrandColors.accentFill : BrandColors.attention).frame(width: proxy.size.width * share)
                    }
            }
            .frame(height: 6)
            Text(String(format: L.percentFormat, percent))
                .font(BrandFonts.number(14))
                .foregroundStyle(km / planned >= L.planGood ? BrandColors.accent : BrandColors.attention)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(format: L.planFormat, TodayText.decimal(planned, fractionDigits: 1))), \(percent)%")
    }

    private var stats: some View {
        HStack(alignment: .top, spacing: 8) {
            stat(lastRun.kilometers.map { TodayText.decimal($0, fractionDigits: 1) }, L.kmLabel)
            stat(lastRun.paceSeconds.map { WorkoutFormat.clock($0) }, L.paceLabel)
            stat(lastRun.averageHeartRate.map { "\($0)" }, L.heartRateLabel, color: lastRun.heartRateHigh == true ? BrandColors.attention : BrandColors.text)
            stat(lastRun.elevationGain.map { String(format: L.climbFormat, Int($0.rounded())) }, L.climbLabel)
        }
    }

    private func stat(_ value: String?, _ label: String, color: Color = BrandColors.text) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value ?? "—").font(BrandFonts.number(22)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value ?? "sem dado")")
    }

    private func paceChart(_ splits: [LastRunSplit]) -> some View {
        let data = LastRunBuilder.chart(splits)
        return VStack(alignment: .leading, spacing: 4) {
            Chart {
                ForEach(data.pace) { point in
                    LineMark(x: .value("km", point.km), y: .value("pace", point.value), series: .value("Série", "pace"))
                        .foregroundStyle(BrandColors.accentFill)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
                ForEach(data.heartRate) { point in
                    LineMark(x: .value("km", point.km), y: .value("FC", point.value), series: .value("Série", "fc"))
                        .foregroundStyle(BrandColors.rest.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                }
                if let fade = lastRun.fadeKm {
                    RuleMark(x: .value("km", fade))
                        .foregroundStyle(BrandColors.attention)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: -L.chartPaddingRatio...(1 + L.chartPaddingRatio))
            .frame(height: L.chartHeight)
            HStack {
                (Text("● ").foregroundStyle(BrandColors.accent) + Text(L.chartLegendPace + "   ") + Text("● ").foregroundStyle(BrandColors.rest) + Text(L.chartLegendHeartRate))
                    .font(.caption2)
                    .foregroundStyle(BrandColors.dim)
                Spacer()
                if let fade = lastRun.fadeKm {
                    Text(String(format: L.fadeFormat, fade)).font(.caption2).foregroundStyle(BrandColors.attention)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chartAccessibility(splits))
    }

    private func chartAccessibility(_ splits: [LastRunSplit]) -> String {
        var text = "\(L.chartLegendPace) e \(L.chartLegendHeartRate)"
        if let fade = lastRun.fadeKm { text += ", " + String(format: L.fadeFormat, fade) }
        return text
    }

    private func zones(_ shares: [Double]) -> some View {
        let total = shares.reduce(0, +)
        return GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(Array(shares.enumerated()), id: \.offset) { index, share in
                    if share > 0 {
                        Rectangle().fill(BrandColors.zone(index + 1)).frame(width: max(proxy.size.width * share / total - 2, 1))
                    }
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: L.zonesHeight)
        .accessibilityHidden(true)
    }

    private func recent(_ similar: [LastRunSimilar]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(lastRun.kind.flatMap { L.recentTitles[$0] } ?? C.lastRunTitle).padding(.top, 0).padding(.bottom, 0)
            row(date: currentDateText, km: lastRun.kilometers, climb: lastRun.elevationGain, pace: lastRun.paceSeconds, heartRate: lastRun.averageHeartRate, highlight: true)
            ForEach(similar) { item in
                row(date: item.dateText, km: item.kilometers, climb: item.elevationGain, pace: item.paceSeconds, heartRate: item.averageHeartRate, highlight: false)
            }
        }
    }

    private var currentDateText: String {
        lastRun.day.map { LastRunBuilder.dateText($0.chartDate) } ?? ""
    }

    private func row(date: String, km: Double?, climb: Double?, pace: Double?, heartRate: Int?, highlight: Bool) -> some View {
        let distance = km.map { value -> String in
            let text = TodayText.decimal(value, fractionDigits: 1)
            guard let climb, climb > L.climbShown else { return String(format: L.rowFormat, text) }
            return String(format: L.rowClimbFormat, text, Int(climb.rounded()))
        }
        return HStack(spacing: 6) {
            Text(date).foregroundStyle(highlight ? BrandColors.text : BrandColors.dim).frame(maxWidth: .infinity, alignment: .leading)
            Text(distance ?? "—").frame(width: L.rowDistanceWidth, alignment: .trailing)
            Text(pace.map { WorkoutFormat.clock($0) } ?? "—").frame(width: L.rowPaceWidth, alignment: .trailing)
            Text(heartRate.map { "\($0)" } ?? "—")
                .foregroundStyle(highlight && lastRun.heartRateHigh == true ? BrandColors.attention : BrandColors.text)
                .frame(width: L.rowHeartRateWidth, alignment: .trailing)
        }
        .font(.caption.monospacedDigit().weight(highlight ? .semibold : .regular))
        .foregroundStyle(BrandColors.text)
        .accessibilityElement(children: .combine)
    }
}
