import SwiftUI

struct StrengthDayPicker: View {
    @Binding var weekday: Int
    let blocked: Set<Int>

    private typealias C = TrainerStrengthConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(TrainerText.strengthDayLabel).font(.caption.weight(.bold)).foregroundStyle(BrandColors.dim)
            HStack(spacing: C.dayButtonSpacing) {
                ForEach(1...TrainerConstants.weekdayCount, id: \.self) { day in
                    let selected = day == weekday
                    let isBlocked = blocked.contains(day)
                    Button { weekday = day } label: {
                        Text(C.weekdayLetters[day - 1])
                            .font(.subheadline.weight(.bold))
                            .strikethrough(isBlocked)
                            .foregroundStyle(selected ? BrandColors.onAccent : BrandColors.text)
                            .frame(maxWidth: C.dayButtonSize)
                            .frame(height: C.dayButtonSize)
                            .background(selected ? BrandColors.accentFill : BrandColors.track, in: Circle())
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isBlocked)
                    .opacity(isBlocked ? C.dayBlockedOpacity : 1)
                    .accessibilityLabel(TrainerConstants.weekdayFull[day - 1])
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Text(TrainerStrengthText.dayCaption(selected: weekday, blocked: blocked)).font(.footnote).foregroundStyle(BrandColors.dim)
        }
    }
}
