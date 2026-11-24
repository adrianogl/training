import Insights
import SwiftUI

private typealias C = StrengthLiveViewConstants
private typealias T = StrengthLiveText

struct StrengthLiveView: View {
    let snapshot: StrengthLiveSnapshot
    @State private var showsDone = false
    @State private var editing: LiveStrengthExercise?

    var body: some View {
        let screen = LiveStrengthLive.screen(session: snapshot.session)
        let card = LiveStrengthLive.card(session: snapshot.session, status: snapshot.status)
        let model = StrengthLiveModel.shared
        VStack(alignment: .leading, spacing: C.cardSpacing) {
            header
            StrengthLiveStats(startedAt: snapshot.startedAt, card: card)
            if let now = screen.now {
                DSSectionTitle(T.now).padding(.top, 4)
                StrengthLiveNowCard(now: now, card: card, connected: model.watchConnected, onEdit: { editing = $0 })
            }
            let upcoming = screen.items.filter { $0.state == .pending }
            let later = screen.items.filter { $0.state == .skipped }
            let finished = screen.items.filter { $0.state == .done || $0.state == .leftOut }
            if !upcoming.isEmpty {
                DSSectionTitle(T.upcoming).padding(.top, 4)
                StrengthLiveList(items: upcoming, connected: model.watchConnected, onEdit: { editing = $0 })
            }
            if !later.isEmpty {
                Text(T.later.uppercased()).font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(BrandColors.attention).padding(.top, 4)
                StrengthLiveList(items: later, connected: model.watchConnected, onEdit: { editing = $0 })
            }
            if !finished.isEmpty {
                Button {
                    withAnimation(.snappy) { showsDone.toggle() }
                } label: {
                    HStack {
                        Text(T.doneSection(finished.count, total: screen.items.count + (screen.now == nil ? 0 : 1)))
                            .font(.caption.weight(.bold)).tracking(1.4).textCase(.uppercase).foregroundStyle(BrandColors.strength)
                        Spacer()
                        Image(systemName: showsDone ? "chevron.up" : "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(BrandColors.dim)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                if showsDone {
                    StrengthLiveList(items: finished, connected: model.watchConnected, onEdit: nil)
                }
            }
            if !model.watchConnected {
                Text(T.disconnected).font(.caption).foregroundStyle(BrandColors.dim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.medium).strokeBorder(BrandColors.line, style: StrokeStyle(lineWidth: 1, dash: [4])))
            }
        }
        .sheet(item: $editing) { exercise in
            let block = snapshot.session.plan.block(containing: exercise.id)
            StrengthLiveWeightSheet(
                exercise: exercise,
                setsLeft: max((block?.rounds ?? 0) - (snapshot.session.done[exercise.id]?.count ?? 0), 0),
                planned: LiveStrengthQueue.plannedWeight(exercise, in: snapshot.session),
                connected: model.watchConnected
            ) { weight, bodyweight, nextOnly in
                editing = nil
                model.requestWeight(exercise, weight: weight, bodyweight: bodyweight, nextOnly: nextOnly)
            }
            .presentationDetents([.height(C.weightSheetHeight)])
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
    let connected: Bool
    let onEdit: (LiveStrengthExercise) -> Void
    @State private var confirmsSkip = false

    private var setsDone: Int { now.rows.filter { $0.state == .done }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: C.cardSpacing) {
            VStack(alignment: .leading, spacing: C.cardSpacing) {
                if let round = now.round {
                    roundHeader(round)
                } else {
                    Button { onEdit(now.exercise) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(now.marker).font(.footnote.bold()).foregroundStyle(BrandColors.accent).frame(width: C.markerWidth, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(now.exercise.name).font(.headline).foregroundStyle(BrandColors.text)
                                Text(T.nowSetLine(card: card, now: now)).font(.caption).foregroundStyle(BrandColors.dim)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: C.editSymbol).font(.footnote).foregroundStyle(BrandColors.dim)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                restBox
            }
            .brandCard()
            DSSectionTitle(now.round == nil ? T.setsSection : T.roundsSection).padding(.top, 4)
            Group {
                if let round = now.round { roundTable(round) } else { table }
            }
            .brandCard()
            skipButton
        }
        .sheet(isPresented: $confirmsSkip) {
            StrengthLiveSkipSheet(
                name: now.exercise.name, done: setsDone, rounds: now.rounds,
                onSkip: {
                    confirmsSkip = false
                    StrengthLiveModel.shared.request(.skip, exerciseId: now.exercise.id)
                },
                onCancel: { confirmsSkip = false }
            )
            .presentationDetents([.height(C.sheetHeight)])
        }
    }

    private var skipButton: some View {
        let sending = StrengthLiveModel.shared.pendingCommand?.exerciseId == now.exercise.id
        return Button {
            if setsDone > 0 { confirmsSkip = true } else { StrengthLiveModel.shared.request(.skip, exerciseId: now.exercise.id) }
        } label: {
            HStack(spacing: 8) {
                if sending { ProgressView().tint(BrandColors.attention) }
                Text(sending ? T.sending : T.skipAction).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(BrandColors.attention)
        .disabled(!connected || StrengthLiveModel.shared.pendingCommand != nil)
        .opacity(connected ? 1 : C.pendingOpacity)
    }

    private var restBox: some View {
        StrengthLiveMomentBand(card: card)
    }

    private func roundHeader(_ round: LiveStrengthRound) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(round.letter).font(.footnote.bold()).foregroundStyle(BrandColors.strength).frame(width: C.markerWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(T.roundTitle(round.letter, number: round.number, rounds: now.rounds)).font(.headline).foregroundStyle(BrandColors.text)
                    Text(T.roundSubtitle(round.markers, rest: now.restSeconds)).font(.caption).foregroundStyle(BrandColors.dim)
                }
            }
            ForEach(Array(zip(round.markers, round.exercises)), id: \.1.id) { marker, exercise in
                Button { onEdit(exercise) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(marker).font(.footnote.bold()).foregroundStyle(BrandColors.accent).frame(width: C.markerWidth, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                            Text(T.roundExerciseLine(exercise)).font(.caption).foregroundStyle(BrandColors.dim)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: C.editSymbol).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func roundTable(_ round: LiveStrengthRound) -> some View {
        VStack(spacing: 0) {
            roundRow(Text(T.roundColumn), cells: round.markers.map { Text($0) }, last: Text(T.lastShortColumn), header: true)
                .foregroundStyle(BrandColors.dim).padding(.bottom, 6)
            ForEach(round.rows) { row in
                switch row.state {
                case .done:
                    roundRow(Text(C.check + " \(row.number)").foregroundStyle(BrandColors.strength), cells: row.cells.map { Text($0).foregroundStyle(BrandColors.text) }, last: Text(row.last ?? T.none).foregroundStyle(BrandColors.dim))
                        .padding(.vertical, C.rowPadding)
                        .overlay(alignment: .top) { Rectangle().fill(BrandColors.line).frame(height: 1) }
                case .next:
                    roundRow(Text("\(row.number)"), cells: row.cells.map { Text($0) }, last: Text(row.last ?? T.none).foregroundStyle(BrandColors.dim))
                        .foregroundStyle(BrandColors.accent)
                        .padding(.vertical, C.rowPadding - 1)
                        .padding(.horizontal, 8)
                        .overlay(RoundedRectangle(cornerRadius: DSRadius.medium).stroke(BrandColors.accent, lineWidth: 1))
                        .padding(.horizontal, -8)
                case .pending:
                    roundRow(Text("\(row.number)"), cells: row.cells.map { Text($0) }, last: Text(row.last ?? T.none))
                        .foregroundStyle(BrandColors.dim.opacity(C.pendingOpacity))
                        .padding(.vertical, C.rowPadding)
                }
            }
        }
    }

    private func roundRow(_ number: Text, cells: [Text], last: Text, header: Bool = false) -> some View {
        let value: Font = header ? .caption2 : .system(size: C.planSize, weight: .bold, design: .rounded).monospacedDigit()
        return HStack(spacing: 8) {
            number.font(header ? .caption2 : .footnote.monospacedDigit().bold()).frame(width: C.numberWidth, alignment: .leading)
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                cell.font(value).frame(maxWidth: .infinity, alignment: .leading)
            }
            last.font(value).frame(width: C.lastWidth, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
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

struct StrengthLiveSkipSheet: View {
    let name: String
    let done: Int
    let rounds: Int
    let onSkip: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.headline).foregroundStyle(BrandColors.text)
            Text(T.skipConfirmation(done: done, rounds: rounds)).font(.footnote).foregroundStyle(BrandColors.dim).padding(.bottom, 8)
            Button(action: onSkip) {
                Text(T.skipAction).font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(BrandColors.attention)
            .background(BrandColors.attention.opacity(C.restBoxOpacity), in: .rect(cornerRadius: DSRadius.control))
            Text(T.skipExplanation(remaining: max(rounds - done, 0))).font(.caption).foregroundStyle(BrandColors.dim).padding(.horizontal, 4)
            Button(T.cancel, action: onCancel)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(BrandColors.dim)
        }
        .padding(.horizontal, DSSpacing.s5)
        .padding(.top, DSSpacing.s6)
    }
}

struct StrengthLiveList: View {
    let items: [LiveStrengthItem]
    let connected: Bool
    let onEdit: ((LiveStrengthExercise) -> Void)?

    private var groups: [[LiveStrengthItem]] {
        items.reduce(into: [[LiveStrengthItem]]()) { groups, item in
            if item.superset != nil, let last = groups.last?.last, last.blockId == item.blockId {
                groups[groups.count - 1].append(item)
            } else {
                groups.append([item])
            }
        }
    }

    var body: some View {
        let groups = groups
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.first?.id) { index, group in
                Group {
                    if let first = group.first, let letter = first.superset {
                        superset(letter, items: group)
                    } else if let item = group.first {
                        row(item)
                    }
                }
                .padding(.vertical, 10)
                .background {
                    if group.contains(where: { StrengthLiveModel.shared.highlighted == $0.exercise.id }) {
                        RoundedRectangle(cornerRadius: DSRadius.medium).fill(BrandColors.strength.opacity(C.highlightOpacity)).padding(.horizontal, -8)
                    }
                }
                .overlay(alignment: .bottom) {
                    if index < groups.count - 1 { Rectangle().fill(BrandColors.line).frame(height: 1) }
                }
            }
        }
        .brandCard()
    }

    private func row(_ item: LiveStrengthItem) -> some View {
        HStack(spacing: 10) {
            Text(marker(item)).font(.footnote.bold()).foregroundStyle(markerColor(item)).frame(width: C.markerWidth, alignment: .leading)
            editable(item) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.exercise.name).font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.state == .done ? BrandColors.dim : BrandColors.text)
                    Text(item.state == .skipped ? T.remaining(item) : T.itemDetail(item)).font(.caption).foregroundStyle(BrandColors.dim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            trailing(item, progress: T.progress(item))
        }
    }

    private func superset(_ letter: String, items: [LiveStrengthItem]) -> some View {
        let first = items[0]
        let done = items.map(\.setsDone).min() ?? 0
        let state = first.state
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(T.supersetHeader(letter, rounds: first.rounds, rest: first.restSeconds))
                    .font(.caption.weight(.bold)).foregroundStyle(state == .skipped ? BrandColors.attention : BrandColors.strength)
                Spacer(minLength: 8)
                trailing(first, progress: "\(done)/\(first.rounds)")
            }
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Text(item.marker).font(.footnote.bold())
                        .foregroundStyle(state == .done ? BrandColors.strength : state == .leftOut ? BrandColors.dim : BrandColors.accent)
                        .frame(width: C.markerWidth, alignment: .leading)
                    editable(item) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.exercise.name).font(.subheadline.weight(.semibold))
                                .foregroundStyle(state == .done ? BrandColors.dim : BrandColors.text)
                            Text(T.supersetDetail(item)).font(.caption).foregroundStyle(BrandColors.dim)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder private func editable<Content: View>(_ item: LiveStrengthItem, @ViewBuilder content: () -> Content) -> some View {
        if let onEdit, item.state != .done, item.state != .leftOut {
            Button { onEdit(item.exercise) } label: { content().contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            content()
        }
    }

    @ViewBuilder private func trailing(_ item: LiveStrengthItem, progress: String) -> some View {
        if item.state == .skipped, StrengthLiveModel.shared.pendingCommand?.exerciseId == item.exercise.id {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(T.sending).font(.caption).foregroundStyle(BrandColors.dim)
            }
        } else if item.state == .skipped {
            Button(T.doNowAction) { StrengthLiveModel.shared.request(.doNow, exerciseId: item.exercise.id) }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .foregroundStyle(BrandColors.onAccent)
                .background(BrandColors.accentFill, in: Capsule())
                .buttonStyle(.plain)
                .disabled(!connected || StrengthLiveModel.shared.pendingCommand != nil)
                .opacity(connected ? 1 : C.pendingOpacity)
        } else if item.state == .leftOut {
            DSChip(text: T.leftOut, tone: .neutral)
        } else {
            Text(progress).font(.footnote.monospacedDigit().bold())
                .foregroundStyle(item.state == .done ? BrandColors.strength : BrandColors.dim)
        }
    }

    private func marker(_ item: LiveStrengthItem) -> String {
        switch item.state {
        case .done: C.check
        case .skipped: C.later
        default: item.marker
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

struct StrengthLiveToast: View {
    var body: some View {
        if let notice = StrengthLiveModel.shared.notice {
            Text(notice)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(BrandColors.card, in: Capsule())
                .overlay(Capsule().stroke(BrandColors.strength, lineWidth: 1))
                .padding(.horizontal, DSSpacing.s5)
                .padding(.bottom, C.toastBottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct StrengthLiveMomentBand: View {
    let card: LiveStrengthCard

    @ViewBuilder
    var body: some View {
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
            HStack(spacing: 6) {
                Circle().fill(BrandColors.accent).frame(width: C.dotSize, height: C.dotSize)
                (Text(T.doing).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.accent)
                    + Text("  " + T.doingMain(card.target)).font(.system(size: C.doingSize, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(BrandColors.text)
                    + Text(T.doingDetail(card.target, last: card.last)).font(.caption).foregroundStyle(BrandColors.dim))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}
