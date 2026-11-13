import Insights
import Storage
import SwiftData
import SwiftUI
import TrainingCore

struct SidebarRaceCard: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<RaceRecord> { $0.deletedAt == nil }) private var races: [RaceRecord]

    var body: some View {
        let today = Day.today()
        if let race = try? targetRace(in: context, today: today), let day = Day(iso: race.day) {
            VStack(alignment: .leading, spacing: 4) {
                Text(TodayConstants.sidebarRaceTitle)
                    .font(.caption2.weight(.medium))
                    .textCase(.uppercase)
                    .foregroundStyle(BrandColors.race)
                Text(race.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.text)
                    .lineLimit(2)
                Text(TodayText.countdown(days: today.days(until: day), priority: race.priorityLevel.rawValue) ?? "")
                    .font(.caption)
                    .foregroundStyle(BrandColors.dim)
            }
            .glassCard()
            .padding(10)
            .id(races.count)
        }
    }
}
