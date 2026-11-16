import GarminAPI
import SwiftUI

struct StrengthBlockList: View {
    let title: String
    let blocks: [StrengthBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption.weight(.semibold)).tracking(1).textCase(.uppercase).foregroundStyle(BrandColors.dim)
                .padding(.bottom, 6)
            StrengthBlockRows(blocks: blocks)
        }
        .brandCard()
    }
}

struct StrengthBlockRows: View {
    let blocks: [StrengthBlock]
    var showsFirstDivider = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                row(index + 1, block, divider: showsFirstDivider || index > 0)
            }
        }
    }

    private func row(_ number: Int, _ block: StrengthBlock, divider: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)").font(.footnote.weight(.bold)).foregroundStyle(BrandColors.accent).frame(width: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(block.exercises.enumerated()), id: \.offset) { _, exercise in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(exercise.name).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                        if block.note == nil || exercise.weight != nil {
                            Text(StrengthText.setsLabel(block.sets, detail: exercise.detail, weight: exercise.weight)).font(.caption).foregroundStyle(BrandColors.dim)
                        }
                    }
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
