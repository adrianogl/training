import SwiftUI
import WorkoutAnalysis

struct WorkoutRecordsCard: View {
    let hits: [RecordHit]
    let steps: [RecordStep]
    let activityId: Int64

    private typealias C = RecordCardConstants

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s4) {
            if hits.count == 1, let hit = hits.first {
                single(hit)
            } else {
                VStack(alignment: .leading, spacing: DSSpacing.s3) {
                    ForEach(Array(hits.enumerated()), id: \.offset) { _, hit in row(hit) }
                }
                .padding(DSSpacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrandColors.track, in: RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous))
            }
        }
        .brandCard()
        .recordCard(true)
    }

    private func single(_ hit: RecordHit) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s2) {
                Text(WorkoutFormat.clock(hit.effort.seconds))
                    .font(BrandFonts.number(C.timeSize))
                    .foregroundStyle(BrandColors.record)
                Text(RecordText.detail(hit))
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.text)
            }
            Text(RecordText.title(hit))
                .font(.headline)
                .foregroundStyle(BrandColors.text)
            if steps.count > 1 { history }
        }
    }

    private var history: some View {
        let slowest = steps.map(\.seconds).max() ?? 1
        return VStack(spacing: DSSpacing.s2) {
            ForEach(steps, id: \.activityId) { step in
                let isCurrent = step.activityId == activityId
                HStack(spacing: DSSpacing.s2) {
                    Text(isCurrent ? C.today : RecordText.day(step.start))
                        .font(.caption)
                        .foregroundStyle(BrandColors.dim)
                        .frame(width: C.labelWidth, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(isCurrent ? BrandColors.recordFill : BrandColors.neutralBar)
                            .frame(width: proxy.size.width * step.seconds / slowest, height: C.barHeight)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: C.barHeight * 2)
                    Text(WorkoutFormat.clock(step.seconds))
                        .font(BrandFonts.number(15))
                        .foregroundStyle(isCurrent ? BrandColors.record : BrandColors.text)
                }
            }
        }
        .padding(DSSpacing.s4)
        .background(BrandColors.track, in: RoundedRectangle(cornerRadius: DSRadius.medium, style: .continuous))
    }

    private func row(_ hit: RecordHit) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s2) {
            Text(RecordText.label(hit.effort.meters))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.text)
                .frame(width: C.labelWidth, alignment: .leading)
            Text(WorkoutFormat.clock(hit.effort.seconds))
                .font(BrandFonts.number(C.rowTimeSize))
                .foregroundStyle(BrandColors.record)
            Spacer(minLength: DSSpacing.s2)
            Text(RecordText.detail(hit))
                .font(.caption)
                .foregroundStyle(BrandColors.dim)
                .multilineTextAlignment(.trailing)
        }
    }
}
