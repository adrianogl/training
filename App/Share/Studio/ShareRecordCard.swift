import SwiftUI
import WorkoutAnalysis

struct ShareRecordCard: View {
    let source: ShareSource

    private typealias C = ShareStudioConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Logo(showsTagline: false)
            Text(heading.uppercased())
                .font(.system(size: 12, weight: .semibold)).tracking(1.2)
                .foregroundStyle(BrandColors.dim)
            if source.recordHits.count == 1, let hit = source.recordHits.first {
                single(hit)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(source.recordHits.enumerated()), id: \.offset) { _, hit in row(hit) }
                }
                Spacer(minLength: 0)
            }
            Text([source.input.title, source.input.dateText].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 13)).foregroundStyle(BrandColors.dim).lineLimit(1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heading: String {
        source.recordHits.count == 1 ? C.recordTitle : String(format: C.recordsTitleFormat, source.recordHits.count)
    }

    private func single(_ hit: RecordHit) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RecordText.label(hit.effort.meters))
                .font(.system(size: 17, weight: .bold)).foregroundStyle(BrandColors.text)
            ShareRecordNumber(value: WorkoutFormat.clock(hit.effort.seconds), size: C.recordTimeSize, color: BrandColors.text, isRecord: true)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(RecordText.detail(hit))
                .font(.system(size: 13)).foregroundStyle(BrandColors.dim)
            Spacer(minLength: 0)
            ladder
        }
    }

    private var ladder: some View {
        let slowest = source.recordSteps.map(\.seconds).max() ?? 1
        return VStack(spacing: 6) {
            ForEach(source.recordSteps, id: \.activityId) { step in
                let isCurrent = step.activityId == source.recordActivityId
                HStack(spacing: 8) {
                    Text(isCurrent ? C.recordToday : RecordText.day(step.start))
                        .font(.system(size: 11)).foregroundStyle(isCurrent ? BrandColors.text : BrandColors.dim)
                        .frame(width: C.recordDateWidth, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(isCurrent ? BrandColors.recordFill : BrandColors.neutralBar)
                            .frame(width: proxy.size.width * step.seconds / slowest, height: C.recordBarHeight)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(height: C.recordBarHeight * 2)
                    Text(WorkoutFormat.clock(step.seconds))
                        .font(BrandFonts.number(14)).foregroundStyle(isCurrent ? BrandColors.recordFill : BrandColors.dim)
                }
            }
        }
    }

    private func row(_ hit: RecordHit) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(RecordText.label(hit.effort.meters))
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(BrandColors.text)
                .frame(width: 64, alignment: .leading)
            ShareRecordNumber(value: WorkoutFormat.clock(hit.effort.seconds), size: C.recordRowTimeSize, color: BrandColors.text, isRecord: true)
            Spacer(minLength: 4)
            Text(hit.gainSeconds.map { String(format: RecordCardConstants.gainFormat, RecordText.gain($0)) } ?? RecordCardConstants.firstTime)
                .font(.system(size: 12)).foregroundStyle(BrandColors.dim)
        }
    }
}
