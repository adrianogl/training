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
                    onOther: { open(suggested: false) },
                    extraDay: model.extraDay,
                    onKeepDays: { model.keepDays() },
                    onMoreDays: { open(suggested: true, days: model.extraDay?.preference) }
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
            TrainerNewPlanView(isEditing: editor.isEditing, suggestedVolumes: editor.volumes, suggestedDays: editor.days)
        }
        .onAppear { model.markCycleSeen() }
        .onChange(of: model.cycleReview == nil) { _, gone in
            if gone, editor == nil { dismiss() }
        }
    }

    private func leaveWhenGone() {
        if model.cycleReview == nil { dismiss() }
    }

    private func open(suggested: Bool, days: TrainerDayPreference? = nil) {
        let volumes = suggested ? model.suggestedVolumes() : model.cycleEnded ? model.cycleVolumes() : nil
        editor = TrainerCycleEditor(isEditing: !model.cycleEnded, start: volumes?.start, peak: volumes?.peak, days: days)
    }
}

struct TrainerCycleContent: View {
    let plan: TrainerPlan
    let review: TrainerCycleReview
    let ended: Bool
    let onSuggestion: () -> Void
    let onOther: () -> Void
    var extraDay: TrainerExtraDay?
    var onKeepDays: () -> Void = {}
    var onMoreDays: () -> Void = {}
    @State private var showsRule = false

    private var dated: Bool { plan.target.date != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainerPlanGoalRow(plan: plan).brandCard()
            DSSectionTitle(TrainerCycleText.nextTitle).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
            TrainerCycleSuggestionCard(review: review, dated: dated, ended: ended, onSuggestion: onSuggestion, onOther: onOther)
            if let extraDay {
                TrainerExtraDayCard(suggestion: extraDay, currentRuns: plan.dayPreference.runs, keep: onKeepDays, review: onMoreDays)
            }
            if let seconds = review.raceSeconds {
                DSSectionTitle(TrainerCycleText.raceTitle).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
                TrainerCycleRaceCard(seconds: seconds, goal: review.goalSeconds)
            }
            if !review.weeks.isEmpty {
                DSSectionTitle(TrainerCycleText.volumeTitle).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
                TrainerCycleVolumeCard(review: review)
                DSSectionTitle(TrainerCycleText.keyTitle).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
                TrainerCycleKeyCard(review: review)
            }
            DSSectionTitle(TrainerCycleText.bodyTitle).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
            TrainerCycleBodyCard(review: review)
            if !review.predictions.isEmpty {
                DSSectionTitle(TrainerCycleText.formTitle).padding(.top, DSSpacing.sectionTop).padding(.bottom, DSSpacing.sectionBottom)
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
                    CardDisclosure(expanded: showsRule)
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
