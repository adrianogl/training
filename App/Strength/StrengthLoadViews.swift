import Charts
import SwiftUI
import TrainingCore

struct StrengthLoadRow: View {
    let series: StrengthLoadSeries

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(series.name).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.text).lineLimit(2)
                HStack(spacing: 4) {
                    StrengthWorkoutTags(series: series)
                    if series.isNewRecord { StrengthRecordBadge() }
                }
            }
            Spacer(minLength: 6)
            StrengthSparkline(values: series.points.map(\.top), marksRecord: series.isNewRecord)
            VStack(alignment: .trailing, spacing: 1) {
                Text(StrengthText.weightLabel(series.current)).font(BrandFonts.number(17)).foregroundStyle(BrandColors.text)
                Text(series.change.map(StrengthText.changeLabel) ?? StrengthText.firstRecord)
                    .font(.caption2)
                    .foregroundStyle((series.change ?? 0) > 0 ? BrandColors.accent : (series.change ?? 0) < 0 ? BrandColors.attention : BrandColors.dim)
            }
            .frame(width: 70, alignment: .trailing)
            CardLinkBadge()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct StrengthWorkoutTags: View {
    let series: StrengthLoadSeries

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(series.workouts.enumerated()), id: \.offset) { index, title in
                let color = StrengthConstants.workoutColors[index % StrengthConstants.workoutColors.count]
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
    }
}

struct StrengthLoadsCard: View {
    let model: StrengthModel
    var showsHeader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsHeader {
                NavigationLink {
                    StrengthLoadsView(model: model)
                } label: {
                    HStack {
                        StrengthCardHeader(title: StrengthText.loadsTitle)
                        if !model.loadSeries.isEmpty { CardLinkBadge() }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.cardLink)
                .disabled(model.loadSeries.isEmpty)
                .padding(.bottom, 4)
            }
            if model.loadSeries.isEmpty {
                Text(StrengthText.loadsEmpty).font(.footnote).foregroundStyle(BrandColors.dim)
            }
            ForEach(Array(model.loadSeries.prefix(StrengthConstants.loadsCardLimit).enumerated()), id: \.element.id) { index, series in
                NavigationLink {
                    StrengthLoadDetailView(model: model, key: series.key)
                } label: {
                    StrengthLoadRow(series: series)
                }
                .buttonStyle(.cardLink)
                .overlay(alignment: .top) { if index > 0 { Divider().overlay(BrandColors.line) } }
            }
            if !showsHeader && model.loadSeries.count > StrengthConstants.loadsCardLimit {
                NavigationLink {
                    StrengthLoadsView(model: model)
                } label: {
                    CardLinkFooter(title: StrengthText.seeAll).padding(.top, 4)
                }
                .buttonStyle(.cardLink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }
}

struct StrengthLoadsView: View {
    let model: StrengthModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(StrengthText.loadsTitle).font(BrandFonts.display(24)).foregroundStyle(BrandColors.text)
                Text(StrengthText.loadsSubtitle).font(.footnote).foregroundStyle(BrandColors.dim)
                VStack(spacing: 0) {
                    if model.loadSeries.isEmpty {
                        Text(StrengthText.loadsEmpty).font(.footnote).foregroundStyle(BrandColors.dim)
                    }
                    ForEach(Array(model.loadSeries.enumerated()), id: \.element.id) { index, series in
                        NavigationLink {
                            StrengthLoadDetailView(model: model, key: series.key)
                        } label: {
                            StrengthLoadRow(series: series)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) { if index > 0 { Divider().overlay(BrandColors.line) } }
                    }
                }
                .brandCard()
                Text(StrengthText.loadsNote).font(.caption).foregroundStyle(BrandColors.dim)
            }
            .padding(.horizontal, BrandConstants.screenPadding)
            .padding(.bottom, 24)
        }
        .background(BrandBackground())
        .navigationTitle(StrengthText.loadsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StrengthLoadDetailView: View {
    let model: StrengthModel
    let key: String

    var body: some View {
        ScrollView {
            if let series = model.loadSeries(key: key) {
                StrengthLoadDetailContent(series: series)
                    .padding(.horizontal, BrandConstants.screenPadding)
                    .padding(.bottom, 24)
            }
        }
        .background(BrandBackground())
        .navigationTitle(StrengthText.loadsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StrengthLoadDetailContent: View {
    let series: StrengthLoadSeries

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(series.name).font(BrandFonts.display(24)).foregroundStyle(BrandColors.text)
            StrengthWorkoutTags(series: series)
            HStack(spacing: 6) {
                stat(StrengthText.weightLabel(series.current), StrengthText.currentLoad)
                if let change = series.change, let first = series.points.first {
                    stat(StrengthText.changeLabel(change), StrengthText.sinceLabel(first.day))
                }
                if let record = series.record {
                    stat(StrengthText.weightLabel(record.top), StrengthText.recordLabel(record.day))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(StrengthConstants.recordGold, lineWidth: series.isNewRecord ? 1.5 : 0))
                }
            }
            chart(series).brandCard()
            SectionLabel(StrengthText.records)
            VStack(spacing: 0) {
                ForEach(Array(series.points.reversed().enumerated()), id: \.element.id) { index, point in
                    HStack(spacing: 10) {
                        Text(StrengthText.dayLabel(point.day)).font(.caption).foregroundStyle(BrandColors.dim).frame(width: 74, alignment: .leading)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(point.workout).font(.caption.weight(.semibold)).foregroundStyle(color(point.workout, in: series))
                            Text(point.fromWatch ? StrengthText.fromWatch : StrengthText.fromMFIT).font(.caption2).foregroundStyle(BrandColors.dim)
                        }
                        Spacer()
                        Text(StrengthText.loadsList(point.loads)).font(BrandFonts.number(14)).foregroundStyle(BrandColors.text)
                        if series.isNewRecord && point.id == series.points.last?.id { StrengthRecordBadge() }
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) { if index > 0 { Divider().overlay(BrandColors.line) } }
                }
            }
            .brandCard()
        }
    }

    private func chart(_ series: StrengthLoadSeries) -> some View {
        Chart(series.points) { point in
            LineMark(x: .value("Dia", point.day.chartDate), y: .value("Carga", point.top))
                .foregroundStyle(BrandColors.dim.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            PointMark(x: .value("Dia", point.day.chartDate), y: .value("Carga", point.top))
                .foregroundStyle(color(point.workout, in: series))
                .symbolSize(70)
            if series.isNewRecord && point.id == series.points.last?.id {
                PointMark(x: .value("Dia", point.day.chartDate), y: .value("Carga", point.top))
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    .foregroundStyle(StrengthConstants.recordGold)
                    .symbolSize(320)
                    .annotation(position: .top, alignment: .trailing) {
                        Text("\(StrengthText.recordBadge) \(StrengthText.weightLabel(point.top))").font(.caption2.weight(.bold)).foregroundStyle(StrengthConstants.recordGold)
                    }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: StrengthConstants.loadChartHeight)
    }

    private func color(_ workout: String, in series: StrengthLoadSeries) -> Color {
        let index = series.workouts.firstIndex(of: workout) ?? 0
        return StrengthConstants.workoutColors[index % StrengthConstants.workoutColors.count]
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(BrandFonts.number(20)).foregroundStyle(BrandColors.text)
            Text(label).font(.caption2).foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(BrandColors.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BrandColors.cardBorder))
    }
}


struct StrengthRecordBadge: View {
    var body: some View {
        Text(StrengthText.recordBadge)
            .font(.system(size: 9.5, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(StrengthConstants.recordGold, in: Capsule())
    }
}
