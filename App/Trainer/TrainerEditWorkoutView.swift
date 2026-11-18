import Insights
import SwiftUI
import TrainingCore
import WorkoutAnalysis

struct TrainerEditWorkoutView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let iso: String
    var initialSwap: Day?
    @State private var draft: TrainerWorkoutDraft?
    @State private var swapWith: Day?

    private var model: TrainerModel { app.trainer }

    private var workout: TrainerWorkout? { model.row(for: iso)?.workout }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let workout, let draft {
                        Text(TrainerText.editHeading(workout)).font(.title2.weight(.bold)).foregroundStyle(BrandColors.text)
                        valuesCard(workout, draft)
                        swapCard(workout)
                        if workout.edited {
                            Button(TrainerText.revertButton) { revert(workout) }
                                .buttonStyle(.ds(.secondary))
                        }
                    }
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .navigationTitle(TrainerText.editWorkoutTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TrainerText.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(TrainerText.save) { save() }.disabled(draft == nil) }
            }
        }
        .task {
            if draft == nil, let workout { draft = TrainerEngine.draft(of: workout) }
            if swapWith == nil, let initialSwap, let workout, model.swapCandidates(for: workout.day).contains(initialSwap) { swapWith = initialSwap }
        }
    }

    private func valuesCard(_ workout: TrainerWorkout, _ draft: TrainerWorkoutDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DSCardLabel(draft.isQuality ? TrainerText.seriesTitle : TrainerText.workoutEditTitle)
            if draft.isQuality {
                Stepper(
                    "\(TrainerText.repeatsLabel) · \(draft.repeats)",
                    value: Binding(get: { draft.repeats }, set: { self.draft?.repeats = $0 }),
                    in: TrainerEngine.editRepeatsRange
                )
                Stepper(
                    "\(TrainerText.blockLabel) · \(TrainerText.distance(draft.blockMeters))",
                    onIncrement: { self.draft?.blockMeters = TrainerEngine.nextBlockMeters(draft.blockMeters, up: true) },
                    onDecrement: { self.draft?.blockMeters = TrainerEngine.nextBlockMeters(draft.blockMeters, up: false) }
                )
                Stepper(
                    "\(TrainerText.paceLabel) · \(qualityPace(draft.pace))",
                    value: Binding(get: { draft.pace }, set: { self.draft?.pace = $0 }),
                    in: TrainerEngine.editPaceRange, step: TrainerEngine.editPaceStepSeconds
                )
                Stepper(
                    "\(TrainerText.restLabel) · \(WorkoutFormat.clock(draft.restSeconds))",
                    value: Binding(get: { draft.restSeconds }, set: { self.draft?.restSeconds = $0 }),
                    in: TrainerEngine.editRestRange, step: TrainerEngine.editRestStepSeconds
                )
            } else {
                Stepper(
                    "\(TrainerText.totalDistanceLabel) · \(TrainerText.distance(draft.totalMeters))",
                    value: Binding(get: { draft.totalMeters }, set: { self.draft?.totalMeters = $0 }),
                    in: TrainerEngine.editDistanceRange, step: TrainerEngine.editDistanceStepMeters
                )
                Stepper(
                    "\(TrainerText.paceLabel) · \(TrainerText.pace(draft.pace))",
                    value: Binding(get: { draft.pace }, set: { self.draft?.pace = $0 }),
                    in: TrainerEngine.editPaceRange, step: TrainerEngine.editPaceStepSeconds
                )
            }
            let edited = TrainerEngine.applying(draft, to: workout)
            Text(TrainerText.editTotal(total: edited.totalMeters, warmup: draft.isQuality ? warmupMeters(edited) : nil))
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
        }
        .brandCard()
    }

    private func swapCard(_ workout: TrainerWorkout) -> some View {
        let days = model.swapCandidates(for: workout.day)
        return VStack(alignment: .leading, spacing: 8) {
            DSCardLabel(TrainerText.swapTitle)
            if days.isEmpty {
                Text(TrainerText.swapEmpty).font(.footnote).foregroundStyle(BrandColors.dim)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: TrainerConstants.swapColumns), spacing: 6) {
                    ForEach(days, id: \.iso) { day in
                        let chosen = swapWith == day
                        Button { swapWith = chosen ? nil : day } label: {
                            Text(TrainerText.swapChip(day))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(chosen ? BrandColors.accent : BrandColors.dim)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(chosen ? BrandColors.accentGlow : BrandColors.track, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(TrainerText.swapHint).font(.caption2).foregroundStyle(BrandColors.dim)
            }
        }
        .brandCard()
    }

    private func qualityPace(_ pace: Double) -> String {
        TrainerText.paceRange(low: pace - TrainerEngine.editPaceBand, high: pace + TrainerEngine.editPaceBand) ?? TrainerText.pace(pace)
    }

    private func warmupMeters(_ workout: TrainerWorkout) -> Double? {
        workout.steps.first { $0.kind == .warmup }?.meters
    }

    private func save() {
        guard let workout, let draft else { return }
        let edited = TrainerEngine.applying(draft, to: workout)
        let changed = TrainerEngine.draft(of: workout) != draft
        model.saveWorkoutEdit(day: workout.day, edited: changed ? edited : nil, swapWith: swapWith)
        dismiss()
    }

    private func revert(_ workout: TrainerWorkout) {
        Task {
            await model.revertWorkout(workout.day)
            dismiss()
        }
    }
}
