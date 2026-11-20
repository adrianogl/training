import SwiftUI

struct TrainerStrengthLineView: View {
    let line: TrainerStrengthLine

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: TrainerConstants.dayDateWidth, height: 1)
            RoundedRectangle(cornerRadius: 3)
                .fill(BrandColors.strength)
                .frame(width: TrainerConstants.dayBarWidth)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 2) {
                Text(TrainerConstants.strengthTitle)
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
                Text(line.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
            }
            Spacer(minLength: 6)
            if line.isDone {
                Text(TrainerConstants.strengthDone)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.accent)
            }
            TrainerStrengthSourceChip(source: line.source)
        }
    }
}
