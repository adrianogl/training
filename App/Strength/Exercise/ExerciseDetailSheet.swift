import GarminAPI
import Insights
import SwiftUI
import UIKit

struct ExerciseDetailSheet: View {
    let input: ExerciseDetailInput
    @Environment(\.exerciseFeedbackStore) private var feedbackStore
    @Environment(\.exerciseNotesStore) private var notesStore

    init(input: ExerciseDetailInput) {
        self.input = input
    }

    @State private var model: ExerciseDetailModel?

    var body: some View {
        Group {
            if let model {
                ExerciseDetailScreen(model: model)
            }
        }
        .onAppear {
            guard model == nil, let feedbackStore, let notesStore else { return }
            model = ExerciseDetailModel(input: input, feedback: feedbackStore, notes: notesStore)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(BrandColors.background)
    }
}

struct ExerciseDetailScreen: View {
    @State private var model: ExerciseDetailModel
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(model: ExerciseDetailModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollViewReader { proxy in
            scroll
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) { _ in
                    revealNotes(proxy)
                }
                .onChange(of: verticalSizeClass) {
                    revealNotes(proxy)
                }
        }
    }

    private func revealNotes(_ proxy: ScrollViewProxy) {
        guard model.draft != nil else { return }
        withAnimation { proxy.scrollTo(ExerciseDetailConstants.notesAnchor, anchor: .bottom) }
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                header
                ExerciseMediaCarousel(model: model)
                ExerciseFeedbackSection(model: model)
                ExerciseLoadBlock(input: model.input, perHand: model.isPerHand)
                steps
                ExerciseNotesSection(model: model).id(ExerciseDetailConstants.notesAnchor)
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.top, DSSpacing.s6)
            .padding(.bottom, DSSpacing.s6)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollEdgeEffectHidden(true, for: .top)
        .background(BrandColors.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.input.name).font(.title3.weight(.bold)).foregroundStyle(BrandColors.text)
            Text(ExerciseDetailText.header(model.input)).font(.footnote.monospacedDigit()).foregroundStyle(BrandColors.dim)
        }
        .padding(.horizontal, DSSpacing.s1)
    }

    @ViewBuilder
    private var steps: some View {
        let items = model.steps
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.s1) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s2) {
                        Text("\(index + 1).").font(.subheadline.monospacedDigit()).foregroundStyle(BrandColors.dim.opacity(0.75))
                        Text(step).font(.subheadline).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, DSSpacing.s1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(ExerciseDetailText.stepsTitle + ". " + items.joined(separator: " "))
        }
    }
}

struct ExerciseLoadBlock: View {
    let input: ExerciseDetailInput
    let perHand: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous)
        if let suggestion = input.suggestedLoad {
            VStack(alignment: .leading, spacing: DSSpacing.s1) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(TrainerStrengthText.kilograms(suggestion.weight)) kg").font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
                        SuggestedLoadPill()
                    }
                    Spacer()
                    if perHand {
                        Text(ExerciseDetailText.perHand).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                }
                Text(TrainerStrengthText.baseLine(suggestion)).font(.footnote).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                if let calculation = ExerciseDetailText.calculation(suggestion, key: input.key) {
                    Text(calculation).font(.footnote).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, DSSpacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BrandColors.card, in: shape)
            .overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
        } else if input.showsFirstTime {
            Text(TrainerStrengthText.firstTime)
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
                .padding(.horizontal, 12)
                .padding(.vertical, DSSpacing.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandColors.card, in: shape)
                .overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
        }
    }
}

struct SuggestedLoadPill: View {
    var body: some View {
        DSChip(text: ExerciseDetailText.suggestedPill, tone: .attention)
    }
}

extension ExerciseDetailInput {
    static func trainer(_ exercise: GeneratedExercise, day: String?) -> ExerciseDetailInput {
        let catalogExercise = StrengthCatalog.exercise(exercise.exerciseId)
        return ExerciseDetailInput(
            key: .catalog(exercise.exerciseId),
            name: exercise.name,
            dose: ExerciseDetailText.dose(exercise),
            load: exercise.weight.map { "\(TrainerStrengthText.kilograms($0)) kg" },
            suggestedLoad: exercise.suggestedLoad,
            pattern: catalogExercise?.pattern ?? StrengthCatalog.pattern(garminCategory: exercise.category),
            mfitNote: nil,
            workoutDay: day,
            rest: StrengthText.restLabel(Double(exercise.restSeconds)),
            showsFirstTime: exercise.weight == nil && catalogExercise?.takesLoad == true
        )
    }

    static func mfit(_ exercise: StrengthExercise, block: StrengthBlock, day: String?) -> ExerciseDetailInput {
        let key = ExerciseMediaCatalog.shared.key(forMFITName: exercise.name, category: exercise.category)
        let pattern: MovementPattern? = switch key {
        case .catalog(let id): StrengthCatalog.exercise(id)?.pattern ?? exercise.category.flatMap(StrengthCatalog.pattern(garminCategory:))
        case .mfit: exercise.category.flatMap(StrengthCatalog.pattern(garminCategory:))
        }
        return ExerciseDetailInput(
            key: key,
            name: exercise.name,
            dose: StrengthText.setsLabel(block.sets, detail: exercise.detail, weight: nil),
            load: exercise.weight.map(StrengthText.weightLabel),
            suggestedLoad: nil,
            pattern: pattern,
            mfitNote: block.note,
            workoutDay: day,
            rest: StrengthText.restLabel(block.restSeconds)
        )
    }
}
