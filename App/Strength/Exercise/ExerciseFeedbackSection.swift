import SwiftUI

struct ExerciseFeedbackSection: View {
    @Bindable var model: ExerciseDetailModel

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            switch model.panel {
            case .question: verdictOrQuestion
            case .alternatives: alternatives
            case .drawingNote: drawingNote
            }
            if model.feedbackFailed {
                Text(ExerciseDetailText.saveFailed).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.danger).padding(.horizontal, DSSpacing.s1)
            }
        }
    }

    @ViewBuilder
    private var verdictOrQuestion: some View {
        if model.suggestionSaved {
            DSNotice(tone: .success, title: ExerciseDetailText.suggestionSaved, text: ExerciseDetailText.savedHint)
        } else if let current = model.current {
            switch model.verdict(for: current) {
            case .unrated: question
            case .matched(let entry):
                banner(tone: BrandColors.accent, title: String(format: ExerciseDetailText.confirmedFormat, ExerciseDetailText.shortDate(entry.createdAt)), detail: nil)
            case .chosen(let entry):
                banner(tone: BrandColors.accent, title: ExerciseDetailText.chosen, detail: String(format: ExerciseDetailText.chosenFormat, ExerciseDetailText.shortDate(entry.createdAt)))
            case .rejected(let entry):
                banner(tone: BrandColors.attention, title: String(format: ExerciseDetailText.rejectedFormat, ExerciseDetailText.shortDate(entry.createdAt)), detail: nil)
            }
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            Text(ExerciseDetailText.question).font(.footnote).foregroundStyle(BrandColors.dim).padding(.horizontal, DSSpacing.s1)
            HStack(spacing: DSSpacing.s2) {
                choiceButton(ExerciseDetailText.matches) { model.markMatches() }
                choiceButton(ExerciseDetailText.doesNotMatch) { model.markDoesNotMatch() }
            }
        }
    }

    private func banner(tone: Color, title: String, detail: String?) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous)
        return HStack(alignment: .center, spacing: DSSpacing.s2) {
            Image(systemName: tone == BrandColors.accent ? "checkmark" : "xmark").font(.footnote.weight(.bold)).foregroundStyle(tone)
            (Text(title).bold().foregroundStyle(tone) + Text(detail.map { " " + $0 } ?? "").foregroundStyle(BrandColors.text))
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DSSpacing.s2)
            Button { model.undo() } label: {
                Text(ExerciseDetailText.undo)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
                    .underline()
                    .padding(.horizontal, DSSpacing.s2)
                    .frame(minWidth: ExerciseDetailConstants.minTarget, minHeight: ExerciseDetailConstants.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 12)
        .padding(.trailing, DSSpacing.s1)
        .padding(.vertical, DSSpacing.s1)
        .background(tone.opacity(ExerciseDetailConstants.tintOpacity), in: shape)
        .overlay(shape.strokeBorder(tone.opacity(ExerciseDetailConstants.borderOpacity), lineWidth: 1))
    }

    private var alternatives: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            Text(ExerciseDetailText.alternativesQuestion).font(.footnote).foregroundStyle(BrandColors.dim).padding(.horizontal, DSSpacing.s1)
            if model.alternatives.isEmpty {
                Text(ExerciseDetailText.noAlternatives).font(.footnote).foregroundStyle(BrandColors.dim).padding(.horizontal, DSSpacing.s1)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.s2, alignment: .top), count: ExerciseDetailConstants.alternativesLimit), spacing: DSSpacing.s2) {
                    ForEach(model.alternatives) { item in
                        alternative(item)
                    }
                }
            }
            HStack(spacing: DSSpacing.s2) {
                if model.alternativeSource == .freeExerciseDb {
                    choiceButton(ExerciseDetailText.searchWger) { model.searchWger() }
                }
                if model.drawing != nil {
                    choiceButton(ExerciseDetailText.useDrawing) { model.useDrawing() }
                }
            }
        }
    }

    private func alternative(_ item: ExerciseMedia) -> some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous)
        let name = model.alternativeName(item)
        return Button { model.choose(item) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay { ExerciseMediaView(media: item, animates: false, fills: true) }
                    .clipped()
                Text(name)
                    .font(.caption)
                    .foregroundStyle(BrandColors.text)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .padding(.horizontal, DSSpacing.s2)
                    .padding(.bottom, DSSpacing.s2)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(BrandColors.card)
            .clipShape(shape)
            .overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    private var drawingNote: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous)
        return VStack(alignment: .leading, spacing: DSSpacing.s2) {
            (Text(ExerciseDetailText.noneMatchedTitle(searchedWger: model.alternativeSource == .wger)).bold().foregroundStyle(BrandColors.attention) + Text(" " + ExerciseDetailText.switchedToDrawing + " " + ExerciseDetailText.tellDifference).foregroundStyle(BrandColors.text))
                .font(.footnote)
            TextField("", text: $model.suggestion, axis: .vertical)
                .lineLimit(3...6)
                .font(.subheadline)
                .foregroundStyle(BrandColors.text)
                .padding(DSSpacing.s2)
                .frame(minHeight: ExerciseDetailConstants.suggestionMinHeight, alignment: .topLeading)
                .background(BrandColors.background, in: RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous).strokeBorder(BrandColors.line, lineWidth: 1))
                .accessibilityLabel(ExerciseDetailText.tellDifference)
            HStack {
                Spacer()
                Button(ExerciseDetailText.saveSuggestion) { model.saveSuggestion() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.onAccent)
                    .padding(.horizontal, DSSpacing.s4)
                    .padding(.vertical, 9)
                    .background(BrandColors.accentFill, in: .dsInner)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, DSSpacing.s3)
        .background(BrandColors.attention.opacity(ExerciseDetailConstants.tintOpacity), in: shape)
        .overlay(shape.strokeBorder(BrandColors.attention.opacity(ExerciseDetailConstants.borderOpacity), lineWidth: 1))
    }

    private func choiceButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.ds(.secondary))
    }
}
