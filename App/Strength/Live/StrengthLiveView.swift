import Insights
import SwiftUI

private typealias C = StrengthLiveViewConstants
private typealias T = StrengthLiveText

struct StrengthLiveView: View {
    let snapshot: StrengthLiveSnapshot

    var body: some View {
        let screen = LiveStrengthLive.screen(session: snapshot.session)
        let card = LiveStrengthLive.card(session: snapshot.session, status: snapshot.status)
        VStack(alignment: .leading, spacing: C.cardSpacing) {
            header
            StrengthLiveStats(startedAt: snapshot.startedAt, card: card)
            if let now = screen.now {
                DSSectionTitle(T.now).padding(.top, 4)
                StrengthLiveNowCard(now: now, card: card)
            }
            if !screen.items.isEmpty {
                DSSectionTitle(T.workout).padding(.top, 4)
                StrengthLiveList(items: screen.items)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(T.header(snapshot.startedAt)).font(.footnote).foregroundStyle(BrandColors.dim)
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.session.plan.title).font(.system(size: C.titleSize, weight: .heavy)).foregroundStyle(BrandColors.text)
                Spacer()
                DSChip(text: T.onWatch, tone: .strength)
            }
        }
    }
}

struct StrengthLiveStats: View {
    let startedAt: Date
    let card: LiveStrengthCard

    var body: some View {
        StrengthLiveStatsContent(startedAt: startedAt, card: card).brandCard()
    }
}

struct StrengthLiveStatsContent: View {
    let startedAt: Date
    let card: LiveStrengthCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                stat(T.time) { Text(startedAt, style: .timer).foregroundStyle(BrandColors.text) }
                stat(T.heartRate) { Text(card.heartRate.map(String.init) ?? T.none).foregroundStyle(BrandColors.rest) }
                stat(T.sets) {
                    (Text("\(card.setsDone)").foregroundStyle(BrandColors.strength) + Text("/\(card.setsTotal)").font(.system(size: 15, weight: .bold)).foregroundStyle(BrandColors.dim))
                }
            }
            DSProgressBar(value: card.setsTotal > 0 ? Double(card.setsDone) / Double(card.setsTotal) : 0, color: BrandColors.strength, height: StrengthLiveViewConstants.barHeight)
        }
    }

    private func stat(_ label: String, @ViewBuilder value: () -> Text) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(BrandColors.dim)
            value().font(.system(size: C.statSize, weight: .heavy, design: .rounded).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StrengthLiveNowCard: View {
    let now: LiveStrengthNow
    let card: LiveStrengthCard

    var body: some View {
        VStack(alignment: .leading, spacing: C.cardSpacing) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(now.number)").font(.footnote.bold()).foregroundStyle(BrandColors.accent).frame(width: 18, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(now.exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                    Text(T.nowSubtitle(now)).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            restBox
            table
        }
        .brandCard()
    }

    @ViewBuilder private var restBox: some View {
        switch card.moment {
        case .resting, .restOver, .paused:
            let color = card.moment == .resting ? BrandColors.fitness : card.moment == .restOver ? BrandColors.accent : BrandColors.dim
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(card.moment == .resting ? T.rest : card.moment == .restOver ? T.restOver : T.paused)
                        .font(.caption.weight(.semibold)).foregroundStyle(color)
                    if let line = T.nextLine(card.target) { Text(line).font(.caption).foregroundStyle(BrandColors.dim) }
                }
                Spacer()
                if let ends = card.restEndsAt, card.moment != .paused {
                    Group {
                        if card.moment == .resting {
                            Text(timerInterval: Date.now...max(ends, .now), countsDown: true)
                        } else {
                            Text("+") + Text(timerInterval: ends...Date.distantFuture, countsDown: false)
                        }
                    }
                    .font(.system(size: C.restSize, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(card.moment == .resting ? BrandColors.fitness : BrandColors.attention)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(C.restBoxOpacity), in: .dsInner)
        default:
            EmptyView()
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            row(number: Text(T.setColumn), done: Text(T.doneColumn), plan: Text(T.planColumn), last: Text(T.lastColumn), header: true)
                .foregroundStyle(BrandColors.dim).padding(.bottom, 6)
            ForEach(now.rows) { setRow in
                rowView(setRow)
            }
        }
    }

    @ViewBuilder private func rowView(_ setRow: LiveStrengthSetRow) -> some View {
        let last = Text(setRow.last ?? T.none)
        switch setRow.state {
        case .done:
            row(
                number: Text(C.check + " \(setRow.number)").foregroundStyle(BrandColors.strength),
                done: doneText(setRow).font(.system(size: C.doneSize, weight: .heavy, design: .rounded).monospacedDigit()),
                plan: Text(setRow.plan).foregroundStyle(BrandColors.dim),
                last: last.foregroundStyle(BrandColors.dim)
            )
            .padding(.vertical, C.rowPadding)
            .overlay(alignment: .top) { Rectangle().fill(BrandColors.line).frame(height: 1) }
        case .next:
            row(
                number: Text("\(setRow.number)").foregroundStyle(BrandColors.accent),
                done: Text(T.next).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.accent),
                plan: Text(setRow.plan).foregroundStyle(BrandColors.accent),
                last: last.foregroundStyle(BrandColors.dim)
            )
            .padding(.vertical, C.rowPadding - 1)
            .padding(.horizontal, 8)
            .overlay(RoundedRectangle(cornerRadius: DSRadius.medium).stroke(BrandColors.accent, lineWidth: 1))
            .padding(.horizontal, -8)
        case .pending:
            row(number: Text("\(setRow.number)"), done: Text(T.none), plan: Text(setRow.plan), last: last)
                .foregroundStyle(BrandColors.dim.opacity(C.pendingOpacity))
                .padding(.vertical, C.rowPadding)
        }
    }

    private func doneText(_ setRow: LiveStrengthSetRow) -> Text {
        guard let result = setRow.done, let reps = result.reps, let weight = result.weight, weight > 0 else {
            return Text(setRow.doneText ?? T.none).foregroundStyle(setRow.repsBelow ? BrandColors.attention : BrandColors.text)
        }
        return Text("\(reps)").foregroundStyle(setRow.repsBelow ? BrandColors.attention : BrandColors.text)
            + Text(" × ").foregroundStyle(BrandColors.text)
            + Text(T.kilograms(weight)).foregroundStyle(setRow.weightChanged ? BrandColors.attention : BrandColors.text)
    }

    private func row(number: Text, done: Text, plan: Text, last: Text, header: Bool = false) -> some View {
        let value: Font = header ? .caption2 : .system(size: C.planSize, weight: .bold, design: .rounded).monospacedDigit()
        return HStack(spacing: 8) {
            number.font(header ? .caption2 : .footnote.monospacedDigit().bold()).frame(width: C.numberWidth, alignment: .leading)
            (header ? done.font(.caption2) : done).frame(maxWidth: .infinity, alignment: .leading)
            plan.font(value).frame(maxWidth: .infinity, alignment: .leading)
            last.font(value).frame(width: C.lastWidth, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

struct StrengthLiveList: View {
    let items: [LiveStrengthItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 10) {
                    Text(marker(item)).font(.footnote.bold()).foregroundStyle(markerColor(item)).frame(width: 18, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.exercise.name).font(.subheadline.weight(.semibold))
                            .foregroundStyle(item.state == .done ? BrandColors.dim : BrandColors.text)
                        Text(T.itemDetail(item)).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    Spacer(minLength: 8)
                    if item.state == .skipped {
                        DSChip(text: T.later, tone: .attention)
                    } else if item.state == .leftOut {
                        DSChip(text: T.leftOut, tone: .neutral)
                    } else {
                        Text(T.progress(item)).font(.footnote.monospacedDigit().bold())
                            .foregroundStyle(item.state == .done ? BrandColors.strength : BrandColors.dim)
                    }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if index < items.count - 1 { Rectangle().fill(BrandColors.line).frame(height: 1) }
                }
            }
        }
        .brandCard()
    }

    private func marker(_ item: LiveStrengthItem) -> String {
        switch item.state {
        case .done: C.check
        case .skipped: C.later
        default: "\(item.number)"
        }
    }

    private func markerColor(_ item: LiveStrengthItem) -> Color {
        switch item.state {
        case .done: BrandColors.strength
        case .skipped: BrandColors.attention
        case .leftOut: BrandColors.dim
        case .pending: BrandColors.accent
        }
    }
}
