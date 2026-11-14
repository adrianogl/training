import Insights
import Storage
import SwiftData
import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct GoalsCard: View {
    let snapshots: [GoalSnapshot]

    private typealias C = GoalsConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionLabel(C.cardTitle).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                Text(snapshots.count == 1 ? C.cardCountOne : String(format: C.cardCountFormat, snapshots.count))
                    .font(.caption).foregroundStyle(BrandColors.dim)
            }
            ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                if index > 0 { Divider().overlay(BrandColors.line) }
                switch snapshot.progress {
                case .time(let progress): timeRow(snapshot, progress)
                case .continuousLong(let progress): longRow(snapshot, progress)
                }
            }
        }
        .brandCard()
    }

    private func header(_ snapshot: GoalSnapshot, status: (text: String, good: Bool)?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(GoalsText.title(kind: snapshot.kind, distanceKm: snapshot.distanceKm, targetSeconds: snapshot.targetSeconds))
                .font(.headline).foregroundStyle(BrandColors.text)
            Spacer()
            if let status {
                Text(status.text)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .foregroundStyle(status.good ? BrandColors.accent : BrandColors.attention)
                    .background((status.good ? BrandColors.accentFill : BrandColors.attention).opacity(0.15), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private func timeRow(_ snapshot: GoalSnapshot, _ progress: TimeGoalProgress) -> some View {
        let target = snapshot.targetSeconds ?? 0
        VStack(alignment: .leading, spacing: 8) {
            header(snapshot, status: timeStatus(progress))
            if let today = progress.todaySeconds {
                GoalPredictionBar(today: today, target: target).frame(height: C.barHeight)
                HStack {
                    Text("\(C.todayLabel) ").foregroundStyle(BrandColors.dim) + Text(WorkoutFormat.clock(today)).font(BrandFonts.number(15)).foregroundStyle(BrandColors.text)
                    Spacer()
                    Text("\(C.goalLabel) ").foregroundStyle(BrandColors.dim) + Text(WorkoutFormat.clock(target)).font(BrandFonts.number(15)).foregroundStyle(BrandColors.accent)
                }
                .font(.caption)
                if let note = crossingNote(progress.crossing, deadline: snapshot.deadline) {
                    Text(note).font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(C.noPrediction).font(.caption).foregroundStyle(BrandColors.dim)
            }
        }
    }

    @ViewBuilder
    private func longRow(_ snapshot: GoalSnapshot, _ progress: LongGoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(snapshot, status: progress.runs.isEmpty ? nil : longStatus(progress))
            if progress.runs.isEmpty {
                Text(C.longEmpty).font(.caption).foregroundStyle(BrandColors.dim)
            } else {
                GoalRunBars(runs: progress.runs, goalKm: snapshot.distanceKm).frame(height: C.runsHeight)
                Text(String(format: C.longCaptionFormat, TodayText.decimal(snapshot.distanceKm, fractionDigits: 1), WorkoutFormat.clock(snapshot.paceSecondsPerKm ?? 0)))
                    .font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func timeStatus(_ progress: TimeGoalProgress) -> (text: String, good: Bool)? {
        if let day = progress.achievedOn { return (String(format: C.achievedFormat, shortDay(day)), true) }
        guard let gap = progress.gapSeconds else { return nil }
        return gap <= 0 ? (C.ahead, true) : (String(format: C.remainingFormat, WorkoutFormat.clock(gap)), false)
    }

    private func longStatus(_ progress: LongGoalProgress) -> (text: String, good: Bool) {
        if let day = progress.achievedOn { return (String(format: C.achievedFormat, shortDay(day)), true) }
        return (String(format: C.runsFormat, progress.metCount, progress.runs.count), progress.metCount > 0)
    }

    private func crossingNote(_ crossing: GoalCrossing, deadline: Day?) -> String? {
        switch crossing {
        case .on(let day):
            guard let deadline else { return String(format: C.crossingOnFormat, shortDay(day)) }
            return String(format: C.crossingOnDeadlineFormat, shortDay(day), day <= deadline ? C.beforeDeadline : C.afterDeadline)
        case .alreadyBeaten: return C.crossingBeaten
        case .unreachable: return C.crossingUnreachable
        case .noGoal: return nil
        }
    }

    private func shortDay(_ day: Day) -> String {
        day.chartDate.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
    }
}

struct GoalPredictionBar: View {
    let today: Double
    let target: Double

    var body: some View {
        GeometryReader { proxy in
            let slowest = max(today, target) * 1.08
            let fastest = min(today, target) * 0.97
            let x = { (seconds: Double) in (slowest - seconds) / (slowest - fastest) * proxy.size.width }
            ZStack(alignment: .leading) {
                Capsule().fill(BrandColors.track)
                Capsule()
                    .fill(LinearGradient(colors: [BrandColors.race.opacity(0.25), BrandColors.race.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.height, x(today)))
                Capsule().fill(BrandColors.accent).frame(width: 3, height: proxy.size.height * 2).offset(x: x(target) - 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

struct GoalRunBars: View {
    let runs: [LongRunCheck]
    let goalKm: Double

    var body: some View {
        let highest = max(goalKm, runs.compactMap(\.longestContinuousKm).max() ?? 0)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(runs, id: \.activityId) { run in
                VStack(spacing: 3) {
                    GeometryReader { proxy in
                        let share = run.longestContinuousKm.map { $0 / highest } ?? GoalsConstants.noDataHeightShare
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(run.met == true ? BrandColors.accentFill : run.met == nil ? BrandColors.track : BrandColors.fitness)
                                .frame(height: proxy.size.height * share)
                        }
                    }
                    Text(run.longestContinuousKm.map { TodayText.decimal($0, fractionDigits: 1) } ?? "—")
                        .font(.caption2).foregroundStyle(BrandColors.dim).monospacedDigit()
                }
            }
        }
        .accessibilityHidden(true)
    }
}
