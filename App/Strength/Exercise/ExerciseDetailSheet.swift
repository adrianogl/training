import GarminAPI
import Insights
import SwiftUI

struct ExerciseDetailSheet: View {
    let input: ExerciseDetailInput
    @Environment(\.exerciseFeedbackStore) private var feedbackStore
    @Environment(\.exerciseNotesStore) private var notesStore

    init(input: ExerciseDetailInput) {
        self.input = input
    }

    var body: some View {
        Group {
            if let feedbackStore, let notesStore {
                ExerciseDetailScreen(model: ExerciseDetailModel(input: input, feedback: feedbackStore, notes: notesStore))
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(BrandColors.background)
    }
}

struct ExerciseDetailScreen: View {
    @State private var model: ExerciseDetailModel

    init(model: ExerciseDetailModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s4) {
                header
                ExerciseMediaCarousel(model: model)
                ExerciseFeedbackSection(model: model)
                ExerciseLoadBlock(input: model.input, perHand: model.isPerHand)
                steps
                ExerciseNotesSection(model: model)
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
        Text(ExerciseDetailText.suggestedPill)
            .font(.caption2.weight(.bold))
            .foregroundStyle(BrandColors.attention)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .overlay(Capsule().strokeBorder(BrandColors.attention.opacity(ExerciseDetailConstants.pillBorderOpacity), lineWidth: 1))
    }
}

extension ExerciseDetailInput {
    static func trainer(_ exercise: GeneratedExercise, day: String?) -> ExerciseDetailInput {
        let catalogExercise = StrengthCatalog.exercise(exercise.exerciseId)
        return ExerciseDetailInput(
            key: .catalog(exercise.exerciseId),
            name: exercise.name,
            dose: TrainerStrengthText.dose(exercise),
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
