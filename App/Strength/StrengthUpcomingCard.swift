import SwiftUI

struct StrengthUpcomingCard: View {
    let model: StrengthModel
    var showsHeader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                StrengthCardHeader(title: StrengthText.upcoming)
            }
            if model.upcoming.isEmpty {
                Text(StrengthText.noUpcoming).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            VStack(spacing: 0) {
                ForEach(Array(model.upcoming.enumerated()), id: \.offset) { index, workout in
                    NavigationLink(value: StrengthRoute.workout(workout.id)) {
                        HStack(spacing: 10) {
                            Text(StrengthText.upcomingDay(workout.day))
                                .font(.caption)
                                .foregroundStyle(BrandColors.dim)
                                .frame(width: 74, alignment: .leading)
                            Text(workout.title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.strength)
                            Spacer(minLength: 8)
                            Text(StrengthText.countLabel(exercises: workout.blocks.flatMap(\.exercises).count, sets: workout.totalSets))
                                .font(.caption).foregroundStyle(BrandColors.dim)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(BrandColors.dim)
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { if index > 0 { Divider().overlay(BrandColors.line) } }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}
