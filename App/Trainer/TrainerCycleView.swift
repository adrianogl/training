import Insights
import SwiftUI

struct TrainerCycleView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var editor: TrainerCycleEditor?

    private var model: TrainerModel { app.trainer }

    var body: some View {
        ScrollView {
            if let plan = model.plan, let review = model.cycleReview {
                TrainerCycleContent(
                    plan: plan, review: review, ended: model.cycleEnded,
                    onSuggestion: { open(suggested: true) },
                    onOther: { open(suggested: false) }
                )
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            } else {
                Text(TrainerCycleText.unavailable)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.dim)
                    .brandCard()
                    .padding(.horizontal, BrandConstants.screenPadding)
                    .padding(.top, 8)
            }
        }
        .background(BrandBackground())
        .navigationTitle(TrainerCycleText.analysisTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor, onDismiss: leaveWhenGone) { editor in
            TrainerNewPlanView(isEditing: editor.isEditing, suggestedVolumes: editor.volumes)
        }
        .onAppear { model.markCycleSeen() }
        .onChange(of: model.cycleReview == nil) { _, gone in
            if gone, editor == nil { dismiss() }
        }
    }

    private func leaveWhenGone() {
        if model.cycleReview == nil { dismiss() }
    }

    private func open(suggested: Bool) {
        let volumes = suggested ? model.suggestedVolumes() : model.cycleEnded ? model.cycleVolumes() : nil
        editor = TrainerCycleEditor(isEditing: !model.cycleEnded, start: volumes?.start, peak: volumes?.peak)
    }
}

struct TrainerCycleContent: View {
    let plan: TrainerPlan
    let review: TrainerCycleReview
    let ended: Bool
    let onSuggestion: () -> Void
    let onOther: () -> Void
    @State private var showsRule = false

    private var dated: Bool { plan.target.date != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainerPlanGoalRow(plan: plan).brandCard()
            SectionHeader(TrainerCycleText.nextTitle)
            TrainerCycleSuggestionCard(review: review, dated: dated, ended: ended, onSuggestion: onSuggestion, onOther: onOther)
            if let seconds = review.raceSeconds {
                SectionHeader(TrainerCycleText.raceTitle)
                TrainerCycleRaceCard(seconds: seconds, goal: review.goalSeconds)
            }
            if !review.weeks.isEmpty {
                SectionHeader(TrainerCycleText.volumeTitle)
                TrainerCycleVolumeCard(review: review)
                SectionHeader(TrainerCycleText.keyTitle)
                TrainerCycleKeyCard(review: review)
            }
            SectionHeader(TrainerCycleText.bodyTitle)
            TrainerCycleBodyCard(review: review)
            if !review.predictions.isEmpty {
                SectionHeader(TrainerCycleText.formTitle)
                TrainerCycleFormCard(predictions: review.predictions)
            }
            rule
        }
    }

    private var rule: some View {
        Button { withAnimation { showsRule.toggle() } } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(TrainerCycleText.ruleTitle).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        Text(TrainerCycleText.ruleSubtitle).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: showsRule ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(BrandColors.dim)
                }
                if showsRule {
                    ForEach(TrainerCycleText.ruleLines, id: \.self) { line in
                        Text(line).font(.footnote).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .brandCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
    }
}
