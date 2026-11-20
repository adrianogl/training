import SwiftUI

struct ExerciseNotesSection: View {
    @Bindable var model: ExerciseDetailModel

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            if model.draft != nil {
                editor
            } else {
                list
            }
            if model.notesFailed {
                Text(ExerciseDetailText.saveFailed).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.danger).padding(.horizontal, DSSpacing.s1)
            }
        }
    }

    private var list: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(ExerciseDetailText.notesTitle).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.dim)
                Spacer()
                Button(ExerciseDetailText.addNote) { model.addNote() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
                    .frame(minHeight: 32)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
            ForEach(model.notes) { note in
                item(text: note.text, caption: ExerciseDetailText.shortDate(note.createdAt), dimmed: false)
                    .contentShape(Rectangle())
                    .onTapGesture { model.edit(note) }
                    .contextMenu {
                        Button(ExerciseDetailText.edit) { model.edit(note) }
                        Button(ExerciseDetailText.delete, role: .destructive) { model.delete(note) }
                    }
                    .accessibilityAction(named: ExerciseDetailText.edit) { model.edit(note) }
                    .accessibilityAction(named: ExerciseDetailText.delete) { model.delete(note) }
            }
            if let mfit = model.input.mfitNote {
                item(text: mfit, caption: ExerciseDetailText.mfitLabel, dimmed: true)
            }
        }
        .background(BrandColors.card, in: shape)
        .overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
    }

    private func item(text: String, caption: String, dimmed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(.subheadline).foregroundStyle(dimmed ? BrandColors.dim : BrandColors.text).fixedSize(horizontal: false, vertical: true)
            Text(caption).font(.caption).foregroundStyle(BrandColors.dim.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Rectangle().fill(BrandColors.line).frame(height: 1) }
    }

    private var editor: some View {
        let shape = RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous)
        return VStack(alignment: .leading, spacing: DSSpacing.s2) {
            Text(ExerciseDetailText.noteLabel).font(.footnote).foregroundStyle(BrandColors.dim).padding(.horizontal, DSSpacing.s1)
            TextField("", text: Binding(get: { model.draft?.text ?? "" }, set: { model.draft?.text = $0 }), axis: .vertical)
                .lineLimit(3...8)
                .font(.body)
                .foregroundStyle(BrandColors.text)
                .padding(DSSpacing.s3)
                .frame(minHeight: ExerciseDetailConstants.editorMinHeight, alignment: .topLeading)
                .background(BrandColors.card, in: shape)
                .overlay(shape.strokeBorder(BrandColors.cardBorder, lineWidth: 1))
                .accessibilityLabel(ExerciseDetailText.noteLabel)
            HStack(spacing: DSSpacing.s2) {
                Button(ExerciseDetailText.cancel) { model.cancelDraft() }.buttonStyle(.ds(.secondary))
                Button(ExerciseDetailText.save) { model.saveDraft() }.buttonStyle(.ds(.primary))
            }
        }
    }
}
