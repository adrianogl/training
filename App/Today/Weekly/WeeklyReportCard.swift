import Insights
import SwiftUI
import TrainingCore

struct WeeklyReportCard: View {
    let report: WeeklyReport
    var strength: WeeklyStrengthSummary?
    var sources: [StrengthSourceTally] = []

    @Environment(\.horizontalSizeClass) private var sizeClass
    private typealias C = WeeklyReportConstants

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) {
            weekCard
            if report.runCount != nil || report.quality != nil || report.long != nil || report.bestCard != nil || report.race != nil {
                titled(C.highlightsTitle) { highlights }
            }
            if let strength {
                titled(StrengthText.section) { WeeklyStrengthBlock(summary: strength, sources: sources) }
            }
        }
    }

    private func titled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sectionBottom) {
            DSSectionTitle(title).padding(.top, DSSpacing.sectionTop - TodayConstants.rowSpacing)
            content()
        }
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(WeeklyReportBuilder.shortTitle(report.start))
                Spacer()
                Text(report.isComplete ? C.closedState : C.openState).font(.caption).foregroundStyle(BrandColors.dim)
            }
            progress
            WeeklyDaysRow(days: report.days, compact: !isWide, strength: strength?.titles ?? [:])
            if !report.note.isEmpty {
                DSNotice(tone: report.days.contains { $0.state == .missed || $0.state == .partial } ? .attention : .info, text: report.note)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            metrics
            tiles
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bigText)
                .font(BrandFonts.number(34))
                .foregroundStyle(BrandColors.text)
            if let planned = report.plannedKm {
                progressBar(planned: planned)
                HStack {
                    if let percent = report.percent {
                        (Text(String(format: C.percentFormat, percent)).foregroundStyle(percentColor) + Text(C.percentSuffix).foregroundStyle(BrandColors.dim))
                    }
                    Spacer()
                    if let missing = report.missingKm {
                        Text(String(format: C.missingFormat, TodayText.decimal(missing, fractionDigits: 1))).foregroundStyle(BrandColors.dim)
                    }
                }
                .font(.caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressLabel)
    }

    private var bigText: AttributedString {
        let done = TodayText.decimal(report.doneKm, fractionDigits: 1)
        guard let planned = report.plannedKm else { return AttributedString(String(format: C.bigNoPlanFormat, done)) }
        var text = AttributedString(done)
        var tail = AttributedString(String(format: C.bigTailFormat, TodayText.decimal(planned, fractionDigits: 1)))
        tail.font = BrandFonts.number(16)
        tail.foregroundColor = BrandColors.dim
        text.append(tail)
        return text
    }

    private func progressBar(planned: Double) -> some View {
        let scale = max(report.doneKm, planned)
        let fill = scale > 0 ? report.doneKm / scale : 0
        let marker = scale > 0 ? planned / scale : 1
        return DSProgressBar(value: fill, height: C.barHeight, marker: marker)
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            if let count = report.runCount {
                metric(String(format: isWide ? C.countFormat : C.countShortFormat, count.done, count.planned), C.runsLabel, BrandColors.text)
            } else {
                metric("\(report.runs)", C.runsLabel, BrandColors.text)
            }
            if let quality = report.quality {
                metric(
                    String(format: isWide ? C.countFormat : C.countShortFormat, quality.done, quality.planned),
                    isWide ? C.qualityLabel : C.qualityShortLabel,
                    quality.done == quality.planned ? BrandColors.accent : BrandColors.attention
                )
            }
            if let long = report.long {
                let planned = TodayText.decimal(long.plannedKm, fractionDigits: 0)
                let done = long.doneKm > 0 ? TodayText.decimal(long.doneKm, fractionDigits: 1) : C.longNotDone
                metric(
                    isWide ? String(format: C.longFormat, done, planned) : done,
                    C.longLabel,
                    long.doneKm <= 0 ? BrandColors.dim : long.doneKm >= long.plannedKm * C.completeShare ? BrandColors.accent : BrandColors.rest
                )
            }
        }
    }

    private func metric(_ value: String, _ label: String, _ color: Color) -> some View {
        DSStat(value: value, label: label, color: color, boxed: true)
    }

    @ViewBuilder
    private var tiles: some View {
        let content = Group {
            if let best = report.bestCard { bestTile(best) }
            if let race = report.race { raceTile(race) }
        }
        if report.bestCard != nil || report.race != nil {
            if isWide {
                HStack(spacing: 10) { content }
            } else {
                VStack(spacing: 8) { content }
            }
        }
    }

    private func bestTile(_ best: ReportBest) -> some View {
        HStack(spacing: 12) {
            Text("\(best.score)")
                .font(BrandFonts.number(17))
                .foregroundStyle(ScoreBadge.color(for: best.score))
                .frame(width: 42, height: 42)
                .overlay(Circle().strokeBorder(ScoreBadge.color(for: best.score), lineWidth: 3))
            VStack(alignment: .leading, spacing: 1) {
                Text(C.bestTitle).font(.caption).foregroundStyle(BrandColors.dim)
                Text(best.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(best.detail).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 0)
        }
        .tile()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(C.bestTitle): \(best.title), \(best.detail), nota \(best.score)")
    }

    private func raceTile(_ race: ReportRace) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                Text("\(race.days)").font(BrandFonts.number(17))
                Text(race.days == 1 ? C.raceDayUnit : C.raceDaysUnit).font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(BrandColors.race)
            .frame(width: 42, height: 42)
            .background(BrandColors.race.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(C.raceTitle).font(.caption).foregroundStyle(BrandColors.dim)
                Text(raceName(race)).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                if let prediction = race.prediction {
                    Text(String(format: C.racePredictionFormat, prediction)).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            Spacer(minLength: 0)
        }
        .tile()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(C.raceTitle): \(raceName(race)), em \(race.days) dias")
    }

    private func raceName(_ race: ReportRace) -> String {
        guard let day = race.day else { return race.name }
        return String(format: C.raceNameFormat, race.name, WeeklyReportBuilder.dayLabel(day))
    }

    private var percentColor: Color {
        (report.adherence ?? 0) >= TodayConstants.volumePercentGood ? BrandColors.accent : BrandColors.attention
    }

    private var progressLabel: String {
        var parts = [bigTextPlain]
        if let percent = report.percent { parts.append(String(format: C.percentFormat, percent) + C.percentSuffix) }
        if let missing = report.missingKm { parts.append(String(format: C.missingFormat, TodayText.decimal(missing, fractionDigits: 1))) }
        return parts.joined(separator: ", ")
    }

    private var bigTextPlain: String { String(bigText.characters) }
}

private extension View {
    func tile() -> some View {
        padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandColors.track, in: .dsInner)
    }
}
