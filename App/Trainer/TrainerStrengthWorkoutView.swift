import Insights
import SwiftUI
import TrainingCore

struct TrainerStrengthWorkoutView: View {
    @Environment(AppModel.self) private var app
    let iso: String
    let sessionId: UUID
    @State private var revision = 0
    @State private var swapping: GeneratedExercise?
    @State private var showsPain = false
    @State private var detail: ExerciseDetailInput?

    private var day: Day? { Day(iso: iso) }

    private var dayLabel: String {
        guard let day else { return iso }
        if day == Day.today() { return TodayConstants.strengthTodayTitle }
        return day.chartDate.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(WorkoutConstants.locale))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrainerStrengthConstants.rowSpacing) {
                if let day, let workout = app.trainer.strengthWorkout(sessionId: sessionId, day: day) {
                    content(workout)
                }
            }
            .id(revision)
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(TrainerStrengthConstants.workoutTitle)
        .sheet(item: $swapping) { exercise in
            if let day, let workout = app.trainer.strengthWorkout(sessionId: sessionId, day: day) {
                TrainerSwapSheet(exercise: exercise, alternatives: app.trainer.strengthAlternatives(exerciseId: exercise.exerciseId, in: workout, day: day)) { choice in
                    TrainerStrengthPrefsStore().swap(exercise.replacedId ?? exercise.exerciseId, to: choice.id, on: iso)
                    revision += 1
                }
            }
        }
        .sheet(isPresented: $showsPain, onDismiss: { revision += 1 }) { TrainerPainSheet() }
        .sheet(item: $detail, onDismiss: { revision += 1 }) { input in ExerciseDetailSheet(input: input) }
    }

    @ViewBuilder
    private func content(_ workout: GeneratedStrengthWorkout) -> some View {
        let stored = day.flatMap { app.trainer.claudeWorkout(on: $0) }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                DSCardLabel(dayLabel)
                Spacer()
                if day.map(app.trainer.isFreeClaudeDay) == true { ClaudeSourceChip() } else { TrainerStrengthSourceChip(source: .trainer) }
            }
            Text(TrainerStrengthText.focusName(workout.group)).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            Text(TrainerStrengthText.meta(workout)).font(.caption).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
        if let why = stored?.why {
            VStack(alignment: .leading, spacing: 4) {
                Label(ClaudeText.whyTitle, systemImage: ClaudeConstants.symbol).font(.footnote.weight(.bold)).foregroundStyle(ClaudeConstants.color)
                Text(why).font(.footnote).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClaudeConstants.color.opacity(0.10), in: RoundedRectangle(cornerRadius: TrainerStrengthConstants.bannerCorner, style: .continuous))
        }
        ForEach(workout.adjustments, id: \.self) { adjustment in
            TrainerStrengthBanner(adjustment: adjustment) {
                TrainerStrengthPrefsStore().setKeptOriginal(true, on: iso)
                revision += 1
            }
        }
        if workout.exercises.isEmpty {
            Text(TrainerStrengthText.restLabel).font(.subheadline).foregroundStyle(BrandColors.dim).brandCard()
        } else {
            DSSectionTitle(TrainerStrengthConstants.exercisesTitle)
                .padding(.top, DSSpacing.sectionTop - TrainerStrengthConstants.rowSpacing)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    if index > 0 { Divider().overlay(BrandColors.line) }
                    TrainerExerciseRow(exercise: exercise, onOpen: { detail = .trainer(exercise, day: iso) }, onSwap: { swapping = exercise })
                        .padding(.vertical, 9)
                }
            }
            .brandCard()
        }
        Button { showsPain = true } label: {
            Label(TrainerStrengthText.painButton, systemImage: TrainerStrengthConstants.painSymbol)
        }
        .buttonStyle(.ds(.secondary))
        if let day, stored != nil {
            Button(ClaudeText.backToGenerator) {
                app.trainer.claudeStore.remove(day)
                revision += 1
            }
            .buttonStyle(.ds(.secondary))
        }
    }
}

struct TrainerExerciseRow: View {
    let exercise: GeneratedExercise
    let onOpen: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: onOpen) {
                HStack(alignment: .center, spacing: 12) {
                    ExerciseThumbnail(key: .catalog(exercise.exerciseId), pattern: StrengthCatalog.exercise(exercise.exerciseId)?.pattern)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text).multilineTextAlignment(.leading)
                        HStack(spacing: 4) {
                            Text(TrainerStrengthText.rowDose(exercise)).font(.caption.monospacedDigit()).foregroundStyle(BrandColors.dim).lineLimit(1).fixedSize()
                            if exercise.suggestedLoad != nil, exercise.replacedName == nil { SuggestedLoadPill() }
                        }
                        if let replaced = exercise.replacedName {
                            Text(String(format: TrainerStrengthText.replacedFormat, replaced)).font(.caption).foregroundStyle(BrandColors.accent)
                        }
                    }
                    Spacer(minLength: 6)
                    Text(String(format: TrainerStrengthText.restShortFormat, exercise.restSeconds)).font(.footnote.monospacedDigit()).foregroundStyle(BrandColors.dim).lineLimit(1).fixedSize()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: ExerciseDetailText.openFormat, exercise.name))
            Button(action: onSwap) {
                Image(systemName: TrainerStrengthConstants.swapSymbol).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.strength)
                    .frame(width: ExerciseDetailConstants.minTarget, height: ExerciseDetailConstants.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: TrainerStrengthText.swapTitleFormat, exercise.name))
        }
    }
}

struct TrainerStrengthBanner: View {
    let adjustment: StrengthAdjustment
    let onKeep: () -> Void

    var body: some View {
        DSNotice(tone: tone, title: TrainerStrengthText.adjustmentTitle(adjustment), text: TrainerStrengthText.adjustmentBody(adjustment)) {
            if TrainerStrengthText.canKeepOriginal(adjustment) {
                Button(TrainerStrengthText.keepOriginal, action: onKeep).buttonStyle(.ds(.text))
            }
        }
    }

    private var tone: DSNoticeTone {
        switch adjustment {
        case .qualityDay: .info
        default: .attention
        }
    }
}

struct TrainerSwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: GeneratedExercise
    let alternatives: [CatalogExercise]
    let onPick: (CatalogExercise) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if alternatives.isEmpty {
                    Text(TrainerStrengthText.swapNone).font(.footnote).foregroundStyle(BrandColors.dim).padding(.vertical, 12)
                }
                ForEach(Array(alternatives.enumerated()), id: \.element.id) { index, option in
                    if index > 0 { Divider().overlay(BrandColors.line) }
                    Button {
                        onPick(option)
                        dismiss()
                    } label: {
                        HStack {
                            Text(option.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                            Spacer()
                            Text(TrainerStrengthText.use).font(.footnote.weight(.bold)).foregroundStyle(BrandColors.strength)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .navigationTitle(String(format: TrainerStrengthText.swapTitleFormat, exercise.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TrainerStrengthText.cancel) { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

struct TrainerPainSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected = TrainerStrengthPrefsStore().load().pain

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(TrainerStrengthText.painHint).font(.footnote).foregroundStyle(BrandColors.dim)
                FlowRegions(selected: $selected)
                Button(TrainerStrengthText.save) {
                    TrainerStrengthPrefsStore().setPain(selected)
                    dismiss()
                }
                .buttonStyle(.ds(.primary))
                Spacer()
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, 8)
            .navigationTitle(TrainerStrengthText.painTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(TrainerStrengthText.cancel) { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct FlowRegions: View {
    @Binding var selected: Set<BodyRegion>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(TrainerStrengthConstants.regionOrder, id: \.self) { region in
                let on = selected.contains(region)
                Button {
                    if on { selected.remove(region) } else { selected.insert(region) }
                } label: {
                    HStack {
                        Text(TrainerStrengthText.regionName(region)).font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    }
                    .foregroundStyle(on ? BrandColors.attention : BrandColors.text)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
