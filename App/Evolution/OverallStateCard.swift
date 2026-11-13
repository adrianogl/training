import SwiftUI

struct OverallStateCard: View {
    let title: String
    let sentence: String
    let rows: [IndicatorRowData]

    private typealias C = EvolutionConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(C.overallTitle).padding(.top, 0).padding(.bottom, 0)
            Text(title).font(.title2.weight(.bold)).foregroundStyle(BrandColors.text)
            if !sentence.isEmpty {
                Text(sentence).font(.subheadline).foregroundStyle(BrandColors.dim)
            }
            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    header(C.columnToday)
                    header(C.columnDelta)
                    header(C.columnGoal)
                }
                Divider().overlay(BrandColors.line)
                ForEach(rows) { row in
                    GridRow {
                        Text(row.name)
                            .font(.footnote)
                            .foregroundStyle(BrandColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        todayCell(row)
                        Text(row.deltaText ?? C.emptyValue)
                            .font(BrandFonts.number(15))
                            .foregroundStyle(EvolutionColors.trend(row.trend))
                        Text(row.goalText ?? C.emptyValue)
                            .font(BrandFonts.number(15))
                            .foregroundStyle(row.goalText == nil ? BrandColors.dim : (row.goalPending ? BrandColors.attention : BrandColors.accent))
                    }
                }
            }
            Text(C.tableLegend).font(.caption2).foregroundStyle(BrandColors.dim)
            if rows.contains(where: \.windowed) {
                Text(C.windowedFootnote).font(.caption2).foregroundStyle(BrandColors.dim)
            }
        }
        .brandCard()
    }

    private func header(_ text: String) -> some View {
        Text(text).font(.caption2).foregroundStyle(BrandColors.dim).lineLimit(1)
    }

    private func todayCell(_ row: IndicatorRowData) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(row.todayText).font(BrandFonts.number(15)).foregroundStyle(BrandColors.text)
            if row.windowed {
                Text(C.windowedToday).font(.system(size: 9)).foregroundStyle(BrandColors.dim).lineLimit(1)
            }
        }
    }
}
