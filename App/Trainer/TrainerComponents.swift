import Insights
import SwiftUI
import TrainingCore

struct TrainerBetaBadge: View {
    var body: some View {
        Text(TrainerText.beta)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(BrandColors.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(BrandColors.attention, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct TrainerStrengthTag: View {
    let line: TrainerStrengthLine

    var body: some View {
        Text(TrainerText.strengthTag(line))
            .font(.caption.weight(.semibold))
            .foregroundStyle(BrandColors.strength)
    }
}

struct TrainerDayRowView: View {
    let row: TrainerDayRow
    let isToday: Bool

    var body: some View {
        let workout = row.workout
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(TrainerText.weekdayShort(workout.day))
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                Text("\(workout.day.day)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
            }
            .frame(width: TrainerConstants.dayDateWidth, alignment: .leading)
            kindBar(workout.kind)
            VStack(alignment: .leading, spacing: 1) {
                Text(workout.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
                let summary = TrainerText.summaryLine(workout)
                if !summary.isEmpty || !row.strength.isEmpty {
                    HStack(spacing: 6) {
                        if !summary.isEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(BrandColors.dim)
                        }
                        ForEach(row.strength) { TrainerStrengthTag(line: $0) }
                    }
                }
            }
            Spacer(minLength: 6)
            if let status = TrainerText.status(for: row) {
                Text(status.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TrainerConstants.color(for: status.tone))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isToday ? BrandColors.accentGlow : BrandColors.card, in: shape)
        .overlay {
            if row.isChanged {
                shape.strokeBorder(BrandColors.attention.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            } else {
                shape.strokeBorder(isToday ? BrandColors.accent.opacity(0.6) : BrandColors.cardBorder, lineWidth: 1)
            }
        }
        .opacity(workout.kind == .off ? 0.55 : 1)
        .contentShape(shape)
    }

    @ViewBuilder
    private func kindBar(_ kind: TrainerDayKind) -> some View {
        let color = TrainerConstants.color(for: kind)
        RoundedRectangle(cornerRadius: 3)
            .fill(kind == .optionalEasy ? color.opacity(0.45) : color)
            .frame(width: TrainerConstants.dayBarWidth)
            .frame(maxHeight: .infinity)
    }
}

struct TrainerWeekStrip: View {
    let cells: [TrainerWeekCell]
    let weeksText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(TrainerText.weeksLabel).padding(.vertical, 0)
                Spacer()
                Text(weeksText).font(.caption).foregroundStyle(BrandColors.dim)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TrainerConstants.stripSpacing) {
                    ForEach(cells) { cell in
                        TrainerWeekCellView(cell: cell)
                    }
                }
            }
            HStack(spacing: 12) {
                ForEach(TrainerText.phases, id: \.0) { phase, name in
                    HStack(spacing: 5) {
                        Capsule().fill(TrainerConstants.color(for: phase)).frame(width: 9, height: 4)
                        Text(name).font(.caption2).foregroundStyle(BrandColors.dim)
                    }
                }
            }
        }
        .brandCard()
    }
}

struct TrainerWeekCellView: View {
    let cell: TrainerWeekCell

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(alignment: .leading, spacing: 2) {
            Capsule()
                .fill(cell.phase.map(TrainerConstants.color(for:)) ?? BrandColors.accentFill)
                .frame(height: 4)
                .padding(.bottom, 3)
            Text(cell.title).font(.system(size: 10.5)).foregroundStyle(cell.isRace ? BrandColors.accent : BrandColors.dim)
            Text(cell.kilometers).font(BrandFonts.number(13)).foregroundStyle(cell.isRace ? BrandColors.accent : BrandColors.text)
            Text(cell.detail).font(.system(size: 10.5)).foregroundStyle(cell.isRace ? BrandColors.accent : BrandColors.dim)
        }
        .padding(6)
        .frame(width: TrainerConstants.stripCellWidth, alignment: .leading)
        .background(cell.isRace ? BrandColors.accentGlow : cell.isCurrent ? BrandColors.accentGlow : BrandColors.track, in: shape)
        .overlay {
            if cell.isChanged {
                shape.strokeBorder(BrandColors.attention.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            } else if cell.isCurrent {
                shape.strokeBorder(BrandColors.accent.opacity(0.7), lineWidth: 1)
            }
        }
        .opacity(cell.isPast ? 0.6 : 1)
    }
}

struct TrainerShapeChart: View {
    let bars: [TrainerShapeBar]

    var body: some View {
        let total = max(bars.map(\.meters).reduce(0, +), 1)
        GeometryReader { proxy in
            let spacing = TrainerConstants.shapeSpacing * Double(max(bars.count - 1, 0))
            let width = max(proxy.size.width - spacing, 1)
            HStack(alignment: .bottom, spacing: TrainerConstants.shapeSpacing) {
                ForEach(bars) { bar in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(TrainerConstants.color(for: bar.kind))
                        .frame(
                            width: max(width * bar.meters / total, TrainerConstants.shapeMinimumWidth),
                            height: proxy.size.height * TrainerConstants.shapeHeight(for: bar.kind)
                        )
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: TrainerConstants.shapeHeight)
    }
}

struct TrainerStepList: View {
    let rows: [TrainerStepRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(TrainerConstants.color(for: row.kind))
                        .frame(width: 10, height: 10)
                    Text(row.title).font(.footnote).foregroundStyle(BrandColors.text)
                    Spacer(minLength: 6)
                    Text(row.detail).font(.footnote).foregroundStyle(BrandColors.dim).monospacedDigit()
                }
                .padding(.vertical, 7)
                if row.id != rows.last?.id {
                    Divider().overlay(BrandColors.line)
                }
            }
        }
    }
}

struct TrainerChangeRow: View {
    let change: TrainerChange

    var body: some View {
        let style = TrainerConstants.style(for: change.kind)
        let color = TrainerConstants.color(for: style.tone)
        HStack(alignment: .top, spacing: 8) {
            Text(style.symbol)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: TrainerConstants.changeSymbolSize, height: TrainerConstants.changeSymbolSize)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(change.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                if let before = change.before, let after = change.after {
                    (Text(before).strikethrough().foregroundStyle(BrandColors.dim)
                        + Text(" → ").foregroundStyle(BrandColors.dim)
                        + Text(after).fontWeight(.semibold).foregroundStyle(BrandColors.accent))
                        .font(.footnote)
                } else if let after = change.after {
                    Text(after).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent)
                }
                Text(change.reason).font(.caption).foregroundStyle(BrandColors.text.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
    }
}

struct TrainerVersionCard: View {
    let version: TrainerVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(TrainerText.versionTitle(version)).padding(.vertical, 0)
                    Spacer()
                    Text(TrainerText.triggerText(version.trigger)).font(.caption).foregroundStyle(BrandColors.dim)
                }
                Text(version.summary).font(.footnote).foregroundStyle(BrandColors.text)
                if case .request(let request) = version.trigger, !request.text.isEmpty {
                    Text(request.text)
                        .font(.footnote.italic())
                        .foregroundStyle(BrandColors.text.opacity(0.85))
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) { Rectangle().fill(BrandColors.accent).frame(width: 3) }
                }
            }
            .brandCard()
            if version.changes.isEmpty {
                Text(TrainerText.noChanges).font(.footnote).foregroundStyle(BrandColors.dim)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(version.changes.enumerated()), id: \.offset) { index, change in
                        if index > 0 { Divider().overlay(BrandColors.line) }
                        TrainerChangeRow(change: change)
                    }
                }
                .brandCard()
            }
        }
    }
}
