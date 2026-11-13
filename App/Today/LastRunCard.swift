import SwiftUI
import WorkoutAnalysis

struct LastRunCard: View {
    let lastRun: LastRunSummary

    private typealias C = TodayConstants

    var body: some View {
        NavigationLink(value: TodayRoute.workout(lastRun.activityId)) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("\(C.lastRunTitle) · \(lastRun.dateText)").padding(.top, 0).padding(.bottom, 0)
                HStack(alignment: .center) {
                    Text(lastRun.title)
                        .font(.headline)
                        .foregroundStyle(BrandColors.text)
                        .lineLimit(2)
                    Spacer()
                    if let score = lastRun.score {
                        ScoreBadge(value: score, size: ScoreConstants.cardBadgeSize)
                    }
                }
                HStack(alignment: .top, spacing: 22) {
                    stat(lastRun.kilometers.map { "\(TodayText.decimal($0, fractionDigits: 1)) km" }, C.lastRunDistance)
                    stat(lastRun.paceSeconds.map { WorkoutFormat.clock($0) + WorkoutConstants.paceUnit }, C.lastRunPace)
                    stat(lastRun.averageHeartRate.map { "\($0) bpm" }, C.lastRunHeartRate)
                }
                if let evolution = lastRun.evolution {
                    Text(evolution)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandColors.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(BrandColors.accentFill.opacity(0.16), in: Capsule())
                    if lastRun.evolutionOnDevice {
                        OnDeviceCaption()
                    }
                } else {
                    Text(C.lastRunNoComparison).font(.caption).foregroundStyle(BrandColors.dim)
                }
                if let notice = lastRun.notice {
                    Text(notice).font(.caption).foregroundStyle(BrandColors.attention)
                }
            }
            .brandCard(fillsHeight: true)
        }
        .buttonStyle(.plain)
    }

    private func stat(_ value: String?, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value ?? "—").font(BrandFonts.number(22)).foregroundStyle(BrandColors.text)
            Text(label).font(.caption2).foregroundStyle(BrandColors.dim)
        }
    }
}
