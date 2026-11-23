import Insights
import SwiftUI
import TrainingCore

private typealias C = StrengthLiveViewConstants
private typealias T = StrengthLiveText

struct StrengthLiveSummaryView: View {
    let snapshot: StrengthLiveSnapshot
    let summary: LiveStrengthSummary
    let nextDay: Day?

    var body: some View {
        VStack(alignment: .leading, spacing: C.cardSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(T.summaryHeader(snapshot.startedAt)).font(.footnote).foregroundStyle(BrandColors.dim)
                Text(snapshot.session.plan.title).font(.system(size: C.titleSize, weight: .heavy)).foregroundStyle(BrandColors.text)
                HStack(spacing: 6) {
                    DSChip(text: T.strength, tone: .strength)
                    if let upload = snapshot.finish?.upload {
                        DSChip(text: T.uploadChip(upload), tone: upload == .failed ? .attention : .neutral)
                    }
                }
            }
            HStack(alignment: .top, spacing: 8) {
                tile(T.volume, value: Text(T.volumeValue(summary.volume)), note: T.volumeChange(summary.volumeChange).map { Text($0).foregroundStyle(BrandColors.strength) })
                tile(T.duration, value: Text(T.durationValue(summary.durationSeconds)), note: summary.averageHeartRate.map {
                    Text(T.averageHR).foregroundStyle(BrandColors.dim) + Text("\($0)").foregroundStyle(BrandColors.rest)
                })
                tile(
                    T.sets,
                    value: Text("\(summary.setsDone)").foregroundStyle(BrandColors.strength) + Text("/\(summary.setsPlanned)").font(.system(size: 16, weight: .bold)).foregroundStyle(BrandColors.dim),
                    note: T.offPlan(summary.offPlan).map { Text($0).foregroundStyle(BrandColors.attention) }
                )
            }
            DSSectionTitle(T.exercises).padding(.top, 4)
            exercises
            nextCard
        }
    }

    @ViewBuilder private var nextCard: some View {
        let loads = LiveStrengthReport.nextLoads(snapshot.session)
        if !loads.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(T.nextTitle(snapshot.session.plan.title, day: nextDay)).font(.footnote.weight(.bold)).foregroundStyle(BrandColors.accent)
                ForEach(loads) { load in
                    HStack {
                        Text(load.name).font(.footnote).foregroundStyle(BrandColors.text).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(T.nextLoad(load)).font(.footnote.monospacedDigit().bold())
                            .foregroundStyle(load.rises ? BrandColors.strength : BrandColors.dim)
                    }
                }
                Text(T.nextNote(rises: loads.contains(where: \.rises))).font(.caption).foregroundStyle(BrandColors.dim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .brandCard()
        }
    }

    private func tile(_ label: String, value: Text, note: Text?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(BrandColors.dim)
            value.font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit()).foregroundStyle(BrandColors.text)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let note { note.font(.caption2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var exercises: some View {
        let items = summary.exercises
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 10) {
                    Text(item.change == .skipped ? T.none : "\(index + 1)").font(.footnote.bold())
                        .foregroundStyle(item.change == .skipped ? BrandColors.dim : BrandColors.accent).frame(width: 18, alignment: .leading)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.name).font(.subheadline.weight(.semibold))
                            .foregroundStyle(item.change == .skipped ? BrandColors.dim : BrandColors.text)
                        StrengthLiveSummaryLine(exercise: snapshot.session.plan.exercise(item.id), sets: item.sets).font(.caption)
                    }
                    Spacer(minLength: 8)
                    switch item.change {
                    case .asPlanned:
                        Text(T.same).font(.footnote.monospacedDigit().bold()).foregroundStyle(BrandColors.dim)
                    case .heavier:
                        DSChip(text: T.change(item.change), tone: .strength)
                    case .lighter, .fewerReps:
                        DSChip(text: T.change(item.change), tone: .attention)
                    case .skipped:
                        DSChip(text: T.change(item.change), tone: .neutral)
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
}

struct StrengthLiveSummaryLine: View {
    let exercise: LiveStrengthExercise?
    let sets: [LiveStrengthSetResult]

    var body: some View {
        text.foregroundStyle(BrandColors.dim).lineLimit(1)
    }

    private var text: Text {
        guard let exercise, !sets.isEmpty else { return Text(T.none) }
        let planReps = exercise.kind == .timed ? exercise.seconds : exercise.reps
        let values = sets.map { exercise.kind == .timed ? $0.seconds : $0.reps }
        let weights = sets.compactMap(\.weight).filter { $0 > 0 }
        var line: Text
        if Set(values).count == 1, let value = values.first {
            line = Text("\(sets.count) × " + (value.map { exercise.kind == .timed ? "\($0) s" : "\($0)" } ?? T.none))
        } else {
            line = values.enumerated().reduce(Text("")) { partial, pair in
                let piece = Text(pair.element.map(String.init) ?? T.none)
                    .foregroundStyle((pair.element ?? 0) < (planReps ?? 0) ? BrandColors.attention : BrandColors.dim)
                return pair.offset == 0 ? piece : partial + Text(", ") + piece
            }
        }
        guard let first = weights.first, let last = weights.last else {
            return exercise.bodyweight ? line + Text(" · peso corporal") : line
        }
        if first == last {
            return line + Text(" · " + T.kilograms(first) + " kg")
        }
        return line + Text(" · " + T.kilograms(first) + " → ") + Text(T.kilograms(last) + " kg").foregroundStyle(BrandColors.attention)
    }
}
