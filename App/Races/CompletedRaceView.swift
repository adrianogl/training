import SwiftUI
import WorkoutAnalysis

struct CompletedRaceView: View {
    let summary: CompletedRaceSummary
    let model: RaceListModel
    @State private var showsEditor = false
    @State private var showsPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                resultCard
                if !summary.splits.isEmpty {
                    splitsCard
                }
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(RacesConstants.lessonTitle).padding(.top, 0).padding(.bottom, 0)
                    Text(summary.lesson)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .brandCard()
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
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                column(RacesConstants.resultLabel, summary.resultSeconds.map(WorkoutFormat.clock) ?? "—", nil, color: BrandColors.accent)
                column(
                    RacesConstants.goalLabel,
                    summary.goalSeconds.map(WorkoutFormat.clock) ?? "—",
                    summary.resultVsGoalText.map { "resultado \($0)" },
                    color: BrandColors.text
                )
                column(
                    RacesConstants.eveLabel,
                    summary.eveSeconds.map(WorkoutFormat.clock) ?? "—",
                    summary.resultVsEveText.map { "resultado \($0)" } ?? summary.eveNote,
                    color: BrandColors.text
                )
            }
            activityLink
        }
        .brandCard()
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
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(RacesConstants.splitsTitle).padding(.top, 0).padding(.bottom, 0)
            ForEach(summary.splits) { split in
                HStack {
                    Text("\(split.index + 1)").frame(width: 30, alignment: .leading).foregroundStyle(BrandColors.dim)
                    Text(RacesText.paceText(split.pace)).fontWeight(.bold).foregroundStyle(BrandColors.text)
                    Spacer()
                    if let planned = split.planned {
                        Text("plano \(WorkoutFormat.clock(planned))").foregroundStyle(BrandColors.dim)
                    }
                }
                .font(.subheadline.monospacedDigit())
            }
        }
        .brandCard()
    }

    private func column(_ label: String, _ value: String, _ detail: String?, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(color == BrandColors.text ? BrandColors.dim : color).multilineTextAlignment(.center)
            Text(value).font(BrandFonts.number(24)).foregroundStyle(color)
            Text(detail ?? " ").font(.caption2).foregroundStyle(BrandColors.dim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
