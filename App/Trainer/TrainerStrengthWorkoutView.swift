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

    private var day: Day? { Day(iso: iso) }

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
        .navigationTitle(TrainerText.strengthTitle)
        .sheet(item: $swapping) { exercise in
            if let day, let workout = app.trainer.strengthWorkout(sessionId: sessionId, day: day) {
                TrainerSwapSheet(exercise: exercise, alternatives: app.trainer.strengthAlternatives(exerciseId: exercise.exerciseId, in: workout)) { choice in
                    TrainerStrengthPrefsStore().swap(exercise.replacedId ?? exercise.exerciseId, to: choice.id, on: iso)
                    revision += 1
                }
            }
        }
        .sheet(isPresented: $showsPain, onDismiss: { revision += 1 }) { TrainerPainSheet() }
    }

    @ViewBuilder
    private func content(_ workout: GeneratedStrengthWorkout) -> some View {
        let stored = day.flatMap { ClaudeStrengthStore().workout(on: $0) }
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(TrainerStrengthText.focusName(workout.group)).font(.title2.weight(.bold)).foregroundStyle(BrandColors.text)
                Spacer()
                if stored != nil { ClaudeSourceChip() }
            }
            Text(TrainerStrengthText.meta(workout)).font(.caption).foregroundStyle(BrandColors.dim)
        }
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
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    if index > 0 { Divider().overlay(BrandColors.line) }
                    exerciseRow(exercise).padding(.vertical, 9)
                }
            }
            .brandCard()
        }
        Button { showsPain = true } label: {
            Label(TrainerStrengthText.painButton, systemImage: TrainerStrengthConstants.painSymbol)
        }
        .buttonStyle(TrainerSecondaryButtonStyle())
        if let day, stored != nil {
            Button(ClaudeText.backToGenerator) {
                ClaudeStrengthStore().remove(day)
                revision += 1
            }
            .buttonStyle(TrainerSecondaryButtonStyle())
        }
    }

    private func exerciseRow(_ exercise: GeneratedExercise) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(TrainerStrengthText.load(exercise))
                    .font(.caption)
                    .foregroundStyle(exercise.replacedName == nil ? BrandColors.dim : BrandColors.accent)
            }
            Spacer(minLength: 6)
            Text(TrainerStrengthText.dose(exercise)).font(BrandFonts.number(15)).foregroundStyle(BrandColors.text)
            Button { swapping = exercise } label: {
                Image(systemName: TrainerStrengthConstants.swapSymbol).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.strength)
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
        let color = color
        let shape = RoundedRectangle(cornerRadius: TrainerStrengthConstants.bannerCorner, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            Text(TrainerStrengthText.adjustmentTitle(adjustment)).font(.subheadline.weight(.bold)).foregroundStyle(color)
            Text(TrainerStrengthText.adjustmentBody(adjustment)).font(.footnote).foregroundStyle(BrandColors.text)
                .fixedSize(horizontal: false, vertical: true)
            if TrainerStrengthText.canKeepOriginal(adjustment) {
                Button(TrainerStrengthText.keepOriginal, action: onKeep)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(color)
                    .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(TrainerStrengthConstants.bannerTint), in: shape)
        .overlay(shape.strokeBorder(color, lineWidth: TrainerStrengthConstants.bannerBorder))
    }

    private var color: Color {
        switch adjustment {
        case .qualityDay: BrandColors.strength
        case .raceWeek, .raceRest: BrandColors.race
        default: BrandColors.attention
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
                .buttonStyle(TrainerPrimaryButtonStyle())
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
