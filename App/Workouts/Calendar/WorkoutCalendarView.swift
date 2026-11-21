import SwiftUI
import TrainingCore

struct WorkoutCalendarView: View {
    @Binding var month: Day
    @Binding var selected: Day
    let days: [String: WorkoutCalendarDay]
    let today: Day

    private typealias C = WorkoutCalendarConstants

    var body: some View {
        VStack(spacing: DSSpacing.s3) {
            HStack {
                navButton(C.previousSymbol, label: C.previousMonth) { month = WorkoutCalendarModel.shift(month, by: -1) }
                Spacer()
                Text(WorkoutCalendarModel.title(month)).font(.headline).foregroundStyle(BrandColors.text)
                Spacer()
                navButton(C.nextSymbol, label: C.nextMonth) { month = WorkoutCalendarModel.shift(month, by: 1) }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: C.cellSpacing), count: 7), spacing: C.cellSpacing) {
                ForEach(Array(C.weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter).font(.caption2.weight(.semibold)).foregroundStyle(BrandColors.dim)
                }
                ForEach(WorkoutCalendarModel.grid(month: month), id: \.iso) { day in cell(day) }
            }
            legend
        }
        .brandCard()
    }

    private func navButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(BrandColors.dim)
                .frame(width: C.navButtonSize, height: C.navButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func cell(_ day: Day) -> some View {
        let info = days[day.iso] ?? WorkoutCalendarDay()
        let inMonth = day.month == month.month && day.year == month.year
        let shape = RoundedRectangle(cornerRadius: C.cellRadius, style: .continuous)
        return Button { selected = day } label: {
            VStack(spacing: C.dotSpacing) {
                Text("\(day.day)").font(.subheadline).monospacedDigit().foregroundStyle(BrandColors.text)
                HStack(spacing: C.dotSpacing) {
                    if info.ran { dot(BrandColors.accentFill) }
                    if info.plannedRun { Circle().strokeBorder(BrandColors.accentFill, lineWidth: 1.5).frame(width: C.dotSize, height: C.dotSize) }
                    if info.strength { dot(BrandColors.strength) }
                    if info.mfit { dot(BrandColors.fitness) }
                }
                .frame(height: C.dotSize)
                Text(info.kilometers > 0 ? "\(Int(info.kilometers.rounded()))" : " ")
                    .font(BrandFonts.number(C.kilometersSize))
                    .foregroundStyle(BrandColors.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, C.cellVerticalPadding)
            .frame(maxWidth: .infinity)
            .background(day == selected ? BrandColors.track : .clear, in: shape)
            .overlay(shape.strokeBorder(day == today ? BrandColors.accentFill : .clear, lineWidth: C.todayBorder))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .opacity(inMonth ? 1 : C.outsideOpacity)
        .accessibilityLabel(WorkoutCalendarModel.dayTitle(day))
        .accessibilityAddTraits(day == selected ? .isSelected : [])
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: C.dotSize, height: C.dotSize)
    }

    private var legend: some View {
        HStack(spacing: DSSpacing.s3) {
            legendItem(C.legendRun) { dot(BrandColors.accentFill) }
            legendItem(C.legendPlanned) { Circle().strokeBorder(BrandColors.accentFill, lineWidth: 1.5).frame(width: C.dotSize, height: C.dotSize) }
            legendItem(C.legendStrength) { dot(BrandColors.strength) }
            legendItem(C.legendMFIT) { dot(BrandColors.fitness) }
        }
        .font(.caption2)
        .foregroundStyle(BrandColors.dim)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(_ text: String, @ViewBuilder mark: () -> some View) -> some View {
        HStack(spacing: 4) { mark(); Text(text) }
    }
}
