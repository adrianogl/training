import Insights
import SwiftUI
import TrainingCore

struct TrainerDayView: View {
    @Environment(AppModel.self) private var app
    let iso: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let row = app.trainer.row(for: iso) {
                    content(row)
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(Day(iso: iso).map(TrainerText.longDate) ?? "")
    }

    @ViewBuilder
    private func content(_ row: TrainerDayRow) -> some View {
        let workout = row.workout
        VStack(alignment: .leading, spacing: 2) {
            Text(workout.title).font(.title2.weight(.bold)).foregroundStyle(BrandColors.text)
            Text(subtitle(workout)).font(.caption).foregroundStyle(BrandColors.dim)
            if !row.strength.isEmpty {
                HStack(spacing: 8) {
                    ForEach(row.strength) { TrainerStrengthTag(line: $0) }
                }
            }
        }
        if !workout.steps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                TrainerShapeChart(bars: TrainerText.shapeBars(workout.steps))
                TrainerStepList(rows: TrainerText.stepRows(workout))
            }
            .brandCard()
        }
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(TrainerText.whyTitle).padding(.vertical, 0)
            Text(workout.rationale).font(.footnote).foregroundStyle(BrandColors.text)
            if let method = workout.method {
                Text(TrainerText.methodLine(method)).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.dim)
            }
            numbers(workout)
        }
        .brandCard()
        if let run = row.run {
            runCard(run)
        }
    }

    private func subtitle(_ workout: TrainerWorkout) -> String {
        var parts = [TrainerText.distance(workout.totalMeters)]
        if let index = app.trainer.weekIndex(of: workout.day) { parts.append("semana \(index) do plano") }
        return parts.joined(separator: " · ")
    }

    private func numbers(_ workout: TrainerWorkout) -> some View {
        var items = [(TrainerText.distance(workout.totalMeters), TrainerText.plannedLabel)]
        if let range = TrainerText.paceRange(low: workout.paceLow, high: workout.paceHigh) {
            items.append((range, TrainerText.paceLabel))
        }
        if let note = workout.note, !note.isEmpty { items.append((note, TrainerText.notePrefix)) }
        return HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.0).font(BrandFonts.number(17)).foregroundStyle(BrandColors.text).lineLimit(2).minimumScaleFactor(0.7)
                    Text(item.1).font(.caption2).foregroundStyle(BrandColors.dim)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func runCard(_ run: TrainerRun) -> some View {
        var items = [(TrainerText.runDistance, TrainerText.distance(run.meters))]
        if let pace = TrainerText.runPace(run) { items.append((TrainerText.runPace, pace)) }
        if let heartRate = run.averageHeartRate { items.append((TrainerText.runHeartRate, "\(Int(heartRate.rounded())) bpm")) }
        if let onTarget = run.activeOnTarget, let total = run.activeTotal { items.append((TrainerText.runOnTarget, "\(onTarget) de \(total)")) }
        if let pauses = run.pauses { items.append((TrainerText.runPauses, "\(pauses)")) }
        if let fade = run.fadeKm { items.append((TrainerText.runFade, "\(fade)")) }
        return VStack(alignment: .leading, spacing: 6) {
            SectionLabel(TrainerText.doneTitle).padding(.vertical, 0)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.0).font(.footnote).foregroundStyle(BrandColors.dim)
                    Spacer()
                    Text(item.1).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.text).monospacedDigit()
                }
            }
        }
        .brandCard()
    }
}
