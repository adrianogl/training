import Charts
import Metrics
import SwiftUI
import WorkoutAnalysis

struct PaceStrategyCard: View {
    let model: NextRaceModel
    @State private var editing: PaceEditTarget?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(RacesConstants.strategyTitle).padding(.top, 0).padding(.bottom, 0)
                Spacer()
                if let target = model.targetText {
                    Text(target)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BrandColors.text)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            switch model.strategyState {
            case .noTarget:
                notice(RacesConstants.strategyNoTarget)
            case .infeasible:
                notice(RacesConstants.strategyInfeasible)
                clearButton(RacesConstants.clearManual)
            case .noGPX, .ok:
                if !model.strategy.isEmpty {
                    paceBars
                }
                if model.strategyState == .noGPX {
                    notice(RacesConstants.strategyNoGPX)
                } else {
                    altitude
                }
                table
                Text(RacesConstants.strategyFootnote).font(.caption2).foregroundStyle(BrandColors.dim)
                if !model.manual.isEmpty {
                    clearButton(RacesConstants.recalculateAll)
                }
            }
        }
        .brandCard()
        .sheet(item: $editing) { target in
            PaceEditor(plan: target.plan, model: model)
                .presentationDetents([.height(320)])
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(BrandColors.dim)
    }

    private func clearButton(_ title: String) -> some View {
        Button(title) { model.clearManualPaces() }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(BrandColors.accent)
    }

    private var altitude: some View {
        let points = model.profile ?? []
        let step = max(1, points.count / 200)
        let sampled = stride(from: 0, to: points.count, by: step).map { points[$0] }
        let low = (sampled.map(\.altitude).min() ?? 0) - 5
        return Chart {
            ForEach(Array(sampled.enumerated()), id: \.offset) { _, point in
                AreaMark(x: .value("Distância", point.distance), yStart: .value("Base", low), yEnd: .value("Altitude", point.altitude))
                    .foregroundStyle(BrandColors.fitness.opacity(0.2))
                LineMark(x: .value("Distância", point.distance), y: .value("Altitude", point.altitude))
                    .foregroundStyle(BrandColors.fitness)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: RacesConstants.altitudeChartHeight)
    }

    private var paceBars: some View {
        let average = model.strategy.map(\.pace).reduce(0, +) / Double(max(model.strategy.count, 1))
        return Chart(model.strategy, id: \.index) { plan in
            BarMark(
                x: .value("Km", plan.index + 1),
                yStart: .value("Média", average),
                yEnd: .value("Pace", plan.pace)
            )
            .foregroundStyle(plan.pace > average ? BrandColors.attention : BrandColors.accentFill)
            .opacity(plan.manual ? 1 : 0.85)
            .cornerRadius(2)
            RuleMark(y: .value("Média", average))
                .foregroundStyle(BrandColors.marker)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .chartYScale(domain: .automatic(includesZero: false, reversed: true))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let pace = value.as(Double.self) { Text(WorkoutFormat.clock(pace)).font(.caption2).foregroundStyle(BrandColors.dim) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in AxisValueLabel().foregroundStyle(BrandColors.dim) }
        }
        .frame(height: RacesConstants.strategyBarsHeight)
    }

    @ViewBuilder
    private var table: some View {
        if sizeClass == .regular {
            let size = Int((Double(model.strategy.count) / Double(RacesConstants.strategyColumns)).rounded(.up))
            HStack(alignment: .top, spacing: 18) {
                ForEach(0..<RacesConstants.strategyColumns, id: \.self) { column in
                    let slice = Array(model.strategy.dropFirst(column * size).prefix(size))
                    tableColumn(slice)
                }
            }
        } else {
            tableColumn(model.strategy)
        }
    }

    private func tableColumn(_ plans: [KmPlan]) -> some View {
        VStack(spacing: 0) {
            row(RacesConstants.strategyHeaders, color: BrandColors.dim, font: .caption2, manual: false)
            ForEach(plans, id: \.index) { plan in
                Button {
                    editing = PaceEditTarget(plan: plan)
                } label: {
                    row(
                        ["\(plan.index + 1)", plan.label, RacesText.grade(plan.grade), WorkoutFormat.clock(plan.pace), WorkoutFormat.clock(model.elapsed(through: plan.index))],
                        color: BrandColors.text,
                        font: .subheadline,
                        manual: plan.manual,
                        labelColor: plan.label == RacesConstants.climbLabel ? BrandColors.race : BrandColors.text
                    )
                }
                .buttonStyle(.plain)
                Divider().overlay(BrandColors.line)
            }
        }
    }

    private func row(_ cells: [String], color: Color, font: Font, manual: Bool, labelColor: Color? = nil) -> some View {
        HStack {
            Text(cells[0]).frame(width: 30, alignment: .leading)
            Text(cells[1]).foregroundStyle(labelColor ?? color).lineLimit(1).frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Text(cells[2]).frame(width: 60, alignment: .trailing)
            Text(cells[3]).fontWeight(.bold).foregroundStyle(manual ? BrandColors.accent : color).frame(width: 52, alignment: .trailing)
            Text(cells[4]).foregroundStyle(BrandColors.dim).frame(width: 70, alignment: .trailing)
        }
        .font(font.monospacedDigit())
        .foregroundStyle(color)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

private struct PaceEditor: View {
    let plan: KmPlan
    let model: NextRaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 5
    @State private var seconds = 0

    var body: some View {
        VStack(spacing: 12) {
            Text(String(format: RacesConstants.paceEditorTitle, plan.index + 1)).font(.headline)
            HStack(spacing: 0) {
                Picker("min", selection: $minutes) {
                    ForEach(RacesConstants.minPaceSeconds / 60...RacesConstants.maxPaceSeconds / 60, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                Text(":")
                Picker("s", selection: $seconds) {
                    ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }
                .pickerStyle(.wheel)
                Text(WorkoutConstants.paceUnit).foregroundStyle(BrandColors.dim)
            }
            .frame(height: 140)
            HStack {
                Button(RacesConstants.cancel) { dismiss() }
                Spacer()
                if plan.manual {
                    Button(RacesConstants.paceEditorClear) {
                        model.releaseManualPace(at: plan.index)
                        dismiss()
                    }
                }
                Spacer()
                Button(RacesConstants.paceEditorSave) {
                    model.setManualPace(Double(minutes * 60 + seconds), at: plan.index)
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundStyle(BrandColors.accent)
            }
        }
        .padding(20)
        .onAppear {
            let total = Int(plan.pace.rounded())
            minutes = min(max(total / 60, RacesConstants.minPaceSeconds / 60), RacesConstants.maxPaceSeconds / 60)
            seconds = total % 60
        }
    }
}
