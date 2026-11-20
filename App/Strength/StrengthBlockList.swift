import GarminAPI
import SwiftUI

struct StrengthBlockList: View {
    let blocks: [StrengthBlock]
    var workoutDay: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StrengthBlockRows(blocks: blocks, showsFirstDivider: false, workoutDay: workoutDay)
        }
        .brandCard()
    }
}

struct StrengthBlockRows: View {
    let blocks: [StrengthBlock]
    var showsFirstDivider = true
    var workoutDay: String?
    @State private var detail: ExerciseDetailInput?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                row(index + 1, block, divider: showsFirstDivider || index > 0)
            }
        }
        .sheet(item: $detail) { input in ExerciseDetailSheet(input: input) }
    }

    private func row(_ number: Int, _ block: StrengthBlock, divider: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)").font(.footnote.weight(.bold)).foregroundStyle(BrandColors.accent).frame(width: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(block.exercises.enumerated()), id: \.offset) { _, exercise in
                    let input = ExerciseDetailInput.mfit(exercise, block: block, day: workoutDay)
                    Button { detail = input } label: {
                        HStack(alignment: .center, spacing: 12) {
                            ExerciseThumbnail(key: input.key, pattern: input.pattern)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text).multilineTextAlignment(.leading)
                                if block.note == nil || exercise.weight != nil {
                                    Text(StrengthText.setsLabel(block.sets, detail: exercise.detail, weight: exercise.weight)).font(.caption).foregroundStyle(BrandColors.dim)
                                }
                            }
                            Spacer(minLength: 6)
                            Image(systemName: StrengthConstants.openSymbol).font(.caption.weight(.semibold)).foregroundStyle(BrandColors.dim.opacity(0.6)).accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(format: ExerciseDetailText.openFormat, exercise.name))
                }
                if let note = block.note {
                    Text(StrengthText.setsLabel(block.sets, detail: note, weight: nil)).font(.caption).foregroundStyle(BrandColors.dim)
                }
                Text(StrengthText.restLabel(block.restSeconds)).font(.caption2).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .top) { if divider { Divider().overlay(BrandColors.line) } }
    }
}
