import Charts
import SwiftUI
import WorkoutAnalysis

struct CompletedRaceView: View {
    let summary: CompletedRaceSummary
    let model: RaceListModel
    @State private var showsEditor = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showsPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                pair {
                    resultCard
                    if !summary.splits.isEmpty {
                        splitsCard
                    }
                }
                if summary.resultSeconds == nil {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(RacesConstants.lessonTitle).padding(.top, 0).padding(.bottom, 0)
                        Text(RacesConstants.lessonNoResult)
                            .font(.footnote)
                            .foregroundStyle(BrandColors.dim)
                    }
                    .brandCard()
                } else {
                    AnalysisCard(
                        columns: summary.lesson,
                        onDevice: false,
                        title: RacesConstants.lessonTitle,
                        expectedTitle: RacesConstants.lessonNextTitle
                    )
                }
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(RacesConstants.editRace) { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor) {
            RaceEditorSheet(raceId: summary.info.id)
        }
        .sheet(isPresented: $showsPicker) {
            ResultPickerSheet(raceId: summary.info.id, model: model)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("prova \(summary.info.priority.rawValue) · \(RacesText.dateText(summary.info.day))")
                    .font(.caption.weight(.medium))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColors.dim)
                if summary.isPR {
                    Text(RacesConstants.prBadge)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(BrandColors.onAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(BrandColors.accentFill, in: Capsule())
                }
            }
            Text(summary.info.name).font(.title2.weight(.bold)).foregroundStyle(BrandColors.text)
            Text(RacesText.distanceText(summary.info.distance)).font(.caption).foregroundStyle(BrandColors.dim)
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(RacesConstants.resultLabel).padding(.top, 0).padding(.bottom, 0)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(summary.resultSeconds.map(WorkoutFormat.clock) ?? "—")
                    .font(BrandFonts.number(TodayConstants.compactCountdownFontSize))
                    .foregroundStyle(BrandColors.text)
                Text(RacesText.distanceText(summary.info.distance)).foregroundStyle(BrandColors.dim)
            }
            if summary.resultSeconds != nil {
                GoalBulletChart(
                    today: summary.eveSeconds,
                    raceDay: summary.resultSeconds,
                    goal: summary.goalSeconds,
                    todayLabel: RacesConstants.eveShort,
                    raceDayLabel: RacesConstants.resultShort
                )
            }
            let parts = [summary.resultVsGoalText.map { "\($0) da meta" }, summary.resultVsEveText.map { "\($0) da previsão da véspera" } ?? summary.eveNote].compactMap { $0 }
            if !parts.isEmpty {
                Text(parts.joined(separator: " · ")).font(.footnote).foregroundStyle(BrandColors.text.opacity(0.85))
            }
            activityLink
        }
        .brandCard(fillsHeight: true)
    }

    @ViewBuilder
    private var activityLink: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let activityId = summary.resultActivityId {
                if summary.resultIsSuggestion {
                    Text(RacesConstants.suggestionNote).font(.caption).foregroundStyle(BrandColors.dim)
                    HStack {
                        actionButton(RacesConstants.useSuggestion) { model.linkResult(raceId: summary.info.id, activityId: activityId) }
                        Spacer()
                        actionButton(RacesConstants.chooseActivity) { showsPicker = true }
                    }
                } else {
                    HStack {
                        NavigationLink(RacesConstants.openActivity, value: activityId)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandColors.accent)
                        Spacer()
                        actionButton(RacesConstants.changeActivity) { showsPicker = true }
                        actionButton(RacesConstants.unlinkActivity) { model.unlinkResult(raceId: summary.info.id) }
                    }
                }
            } else {
                Text(RacesConstants.noActivity).font(.caption).foregroundStyle(BrandColors.dim)
                actionButton(RacesConstants.chooseActivity) { showsPicker = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .foregroundStyle(BrandColors.accent)
    }

    private var splitsCard: some View {
        let average = summary.splits.map(\.pace).reduce(0, +) / Double(max(summary.splits.count, 1))
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(RacesConstants.splitsDivergingTitle).padding(.top, 0).padding(.bottom, 0)
            Chart(summary.splits) { split in
                BarMark(
                    x: .value("Km", split.index + 1),
                    yStart: .value("Média", average),
                    yEnd: .value("Pace", split.pace)
                )
                .foregroundStyle(split.pace > average ? BrandColors.attention : BrandColors.accentFill)
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
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisValueLabel().foregroundStyle(BrandColors.dim)
                }
            }
            .frame(height: RacesConstants.splitsChartHeight)
            Text(String(format: RacesConstants.splitsAverageFormat, WorkoutFormat.clock(average)))
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
        }
        .brandCard(fillsHeight: true)
    }

    @ViewBuilder
    private func pair<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if sizeClass == .regular {
            ProportionalHStack(weights: RacesConstants.pairWeights, spacing: TodayConstants.rowSpacing) { content() }
        } else {
            VStack(alignment: .leading, spacing: TodayConstants.rowSpacing) { content() }
        }
    }

}

private struct ResultPickerSheet: View {
    let raceId: UUID
    let model: RaceListModel
    @Environment(\.dismiss) private var dismiss
    @State private var options: [ResultOption]?

    var body: some View {
        NavigationStack {
            Group {
                if let options {
                    if options.isEmpty {
                        Text(RacesConstants.pickerEmpty).foregroundStyle(BrandColors.dim)
                    } else {
                        List(options) { option in
                            Button {
                                model.linkResult(raceId: raceId, activityId: option.activityId)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title).foregroundStyle(BrandColors.text)
                                        Text(option.dateText).font(.caption).foregroundStyle(BrandColors.dim)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(option.distanceText).font(BrandFonts.number(17)).foregroundStyle(BrandColors.text)
                                        Text(option.durationText).font(BrandFonts.number(14)).foregroundStyle(BrandColors.dim)
                                    }
                                    if option.isLinked {
                                        Image(systemName: "checkmark").foregroundStyle(BrandColors.accent)
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandBackground())
            .navigationTitle(RacesConstants.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(RacesConstants.cancel) { dismiss() }
                }
            }
        }
        .task { options = await model.resultOptions(for: raceId) }
    }
}
