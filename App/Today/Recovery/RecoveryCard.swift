import SwiftUI
import TrainingCore

struct RecoveryCard: View {
    let estimate: RecoveryEstimate

    @Environment(\.horizontalSizeClass) private var sizeClass
    private typealias C = RecoveryConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(C.title)
                Spacer()
                if sizeClass == .regular {
                    Text(C.subtitle).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                source
                Spacer(minLength: 8)
                remaining
            }
            timeline
            if !estimate.upcoming.isEmpty {
                VStack(spacing: 8) {
                    ForEach(estimate.upcoming) { row($0) }
                }
            }
            if let advice = estimate.advice {
                Divider().overlay(BrandColors.line)
                Text(advice).font(.footnote).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: 2) {
            (Text(C.afterPrefix + sourceArticle + " ").foregroundStyle(BrandColors.dim) + Text(sourceName).bold().foregroundStyle(BrandColors.text))
                .font(.subheadline)
            Text(sourceDetail).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .accessibilityElement(children: .combine)
    }

    private var remaining: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if estimate.remainingHours > 0 {
                (Text(String(format: C.hoursRemainingFormat, estimate.remainingHours)).font(BrandFonts.number(30)).foregroundStyle(BrandColors.text)
                    + Text(" " + C.hoursRemainingUnit).font(.caption).foregroundStyle(BrandColors.dim))
                (Text(C.readyCaption + " ").foregroundStyle(BrandColors.dim) + Text(RecoveryText.dayHour(estimate.readyAt)).bold().foregroundStyle(BrandColors.accent))
                    .font(.caption)
            } else {
                Text(C.readyNow).font(BrandFonts.number(24)).foregroundStyle(BrandColors.accent)
                Text(C.readyCaption).font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityElement(children: .combine)
    }

    private var timeline: some View {
        let events = placedEvents
        let height = C.timelineHeight + C.markerRowHeight + (events.map(\.row).max().map { Double($0 + 1) * C.eventRowHeight } ?? 0)
        return GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                Capsule().fill(BrandColors.track).frame(height: C.timelineHeight)
                Capsule()
                    .fill(estimate.progress >= 1 ? BrandColors.accentFill : BrandColors.attention)
                    .frame(width: max(width * estimate.position(of: estimate.now), C.timelineHeight), height: C.timelineHeight)
                pin(x: width * estimate.position(of: estimate.now), color: BrandColors.text, label: C.nowLabel, width: width)
                if estimate.remainingHours > 0 {
                    pin(x: width * estimate.position(of: estimate.readyAt), color: BrandColors.accent, label: String(format: C.readyLabelFormat, RecoveryText.dayHour(estimate.readyAt)), width: width)
                }
                ForEach(events, id: \.next.id) { event in
                    let x = width * estimate.position(of: event.next.start)
                    Circle()
                        .fill(color(event.next.kind))
                        .frame(width: C.eventDotSize, height: C.eventDotSize)
                        .overlay(Circle().strokeBorder(BrandColors.background, lineWidth: 1.5))
                        .offset(x: x - C.eventDotSize / 2, y: (C.timelineHeight - C.eventDotSize) / 2)
                    eventLabel(event.next)
                        .frame(width: C.labelWidth)
                        .offset(x: clamp(x - C.labelWidth / 2, width: width), y: C.timelineHeight + C.markerRowHeight + Double(event.row) * C.eventRowHeight)
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func pin(x: Double, color: Color, label: String, width: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(color).frame(width: 2, height: C.timelineHeight + 8).offset(x: x - 1, y: -4)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: C.labelWidth)
                .offset(x: clamp(x - C.labelWidth / 2, width: width), y: C.timelineHeight + 6)
        }
    }

    private func eventLabel(_ next: RecoveryNext) -> some View {
        VStack(spacing: 0) {
            Text(RecoveryText.name(next)).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.text).lineLimit(1).minimumScaleFactor(0.8)
            Text(RecoveryText.dayHour(next.start)).font(.caption2).foregroundStyle(BrandColors.dim)
        }
    }

    private func row(_ next: RecoveryNext) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(color(next.kind)).frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: C.eventFormat, RecoveryText.name(next), RecoveryText.dayHour(next.start))).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(next.detail).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            chip(next.status)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(RecoveryText.name(next)), \(RecoveryText.dayHour(next.start)), \(next.detail), \(C.statusLabels[next.status] ?? "")")
    }

    private func chip(_ status: RecoveryStatus) -> some View {
        DSChip(text: C.statusLabels[status] ?? "", tone: status == .early ? .danger : (status == .almost ? .attention : .accent))
    }

    private struct PlacedEvent {
        let next: RecoveryNext
        let row: Int
    }

    private var placedEvents: [PlacedEvent] {
        var placed: [PlacedEvent] = []
        for next in estimate.upcoming {
            let x = estimate.position(of: next.start)
            let crowded = placed.contains { abs(estimate.position(of: $0.next.start) - x) * nominalWidth < C.labelWidth && $0.row == 0 }
            placed.append(PlacedEvent(next: next, row: crowded ? 1 : 0))
        }
        return placed
    }

    private var nominalWidth: Double {
        sizeClass == .regular ? C.eventSpreadWide : C.eventSpreadCompact
    }

    private func clamp(_ x: Double, width: Double) -> Double {
        min(max(x, 0), max(width - C.labelWidth, 0))
    }

    private func color(_ kind: SessionKind) -> Color {
        switch kind {
        case .easy: BrandColors.fitness
        case .threshold, .intervals: BrandColors.attention
        case .long, .race: BrandColors.race
        }
    }

    private var sourceArticle: String {
        estimate.kind.flatMap { C.kindArticle[$0] } ?? C.fallbackArticle
    }

    private var sourceName: String {
        let day = Day.today(now: estimate.end)
        let when = day == Day.today(now: estimate.now) ? C.todayWord : WeeklyReportBuilder.weekdayName(day)
        return String(format: C.afterRunFormat, estimate.kind.flatMap { C.kindNoun[$0] } ?? C.fallbackNoun, when)
    }

    private var sourceDetail: String {
        var parts: [String] = []
        if let km = estimate.kilometers { parts.append(String(format: C.kmFormat, TodayText.decimal(km, fractionDigits: 1))) }
        if let heartRate = estimate.averageHeartRate { parts.append(String(format: C.heartRateFormat, heartRate)) }
        parts.append(String(format: C.finishedFormat, RecoveryText.dayHour(estimate.end)))
        return parts.joined(separator: " · ")
    }
}
