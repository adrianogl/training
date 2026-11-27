import Charts
import Insights
import SwiftUI

struct TrainerZoneGuideCard: View {
    let trend: TrainerZoneTrend?
    let hasHeartRate: Bool

    @State private var mode: TrainerZoneChartMode
    @State private var shown: Set<Int>
    @State private var selection: Int?

    init(
        trend: TrainerZoneTrend?, hasHeartRate: Bool, mode: TrainerZoneChartMode = .pace,
        zones: Set<Int> = TrainerZoneGuideConstants.defaultZones
    ) {
        self.trend = trend
        self.hasHeartRate = hasHeartRate
        _mode = State(initialValue: mode)
        _shown = State(initialValue: zones)
    }

    private typealias C = TrainerZoneGuideConstants
    private typealias T = TrainerZoneGuideText

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s4) {
            header
            if let trend, !trend.weeks.isEmpty {
                let index = min(selection ?? trend.weeks.count - 1, trend.weeks.count - 1)
                summary(trend, index: index)
                chartBlock(trend, index: index)
                table(trend, week: trend.weeks[index])
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var header: some View {
        HStack(spacing: DSSpacing.s4) {
            Text(C.title).font(.headline).foregroundStyle(BrandColors.text)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                modeButton(C.paceMode, .pace)
                modeButton(C.heartRateMode, .heartRate)
            }
            .padding(C.modePadding)
            .background(BrandColors.track, in: Capsule())
            .overlay(Capsule().strokeBorder(BrandColors.line, lineWidth: 1))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(C.modeGroup)
        }
    }

    private func modeButton(_ title: String, _ value: TrainerZoneChartMode) -> some View {
        let isOn = mode == value
        return Button { mode = value } label: {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isOn ? BrandColors.card : BrandColors.dim)
                .padding(.horizontal, C.modeHorizontalPadding)
                .frame(minHeight: C.modeHeight)
                .background(isOn ? BrandColors.text : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func summary(_ trend: TrainerZoneTrend, index: Int) -> some View {
        let week = trend.weeks[index]
        var text = Text(C.thresholdLabel) + Text(TrainerText.pace(week.threshold)).fontWeight(.bold).monospacedDigit()
            + Text(C.separator) + Text(T.change(trend, at: index)).fontWeight(.semibold).foregroundStyle(BrandColors.accent)
        if let gap = T.gap(trend, at: index) {
            text = text + Text(C.separator) + Text(gap).foregroundStyle(BrandColors.dim)
        }
        return text
            .font(.subheadline)
            .foregroundStyle(BrandColors.text)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func chartBlock(_ trend: TrainerZoneTrend, index: Int) -> some View {
        let showsGoal = mode == .pace && shown.contains(4) && trend.goalThreshold != nil
        return VStack(alignment: .leading, spacing: DSSpacing.s3) {
            VStack(alignment: .leading, spacing: DSSpacing.s2) {
                Text(C.chartLabel).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(BrandColors.dim)
                HStack(spacing: DSSpacing.s2) {
                    ForEach(C.zones, id: \.self, content: chip)
                }
            }
            chart(trend, index: index, showsGoal: showsGoal)
                .frame(height: C.chartHeight)
            ViewThatFits(in: .horizontal) {
                legend(showsGoal: showsGoal, spacing: DSSpacing.s5)
                legend(showsGoal: showsGoal, spacing: DSSpacing.s2)
                legend(showsGoal: showsGoal, spacing: DSSpacing.s2).scaleEffect(C.compactScale, anchor: .leading)
            }
        }
        .padding(.horizontal, DSSpacing.s4)
        .padding(.vertical, DSSpacing.s4 - 2)
        .background(BrandColors.track, in: .dsInner)
    }

    private func legend(showsGoal: Bool, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            DSLegendItem(text: mode == .pace ? C.paceBandLegend : C.heartRateBandLegend, color: BrandColors.neutralBar.opacity(0.5), mark: .square)
            DSLegendItem(text: mode == .pace ? C.paceLineLegend : C.heartRateLineLegend, color: BrandColors.text)
            if showsGoal { DSLegendItem(text: C.goalLegend, color: BrandColors.race, mark: .dashed) }
        }
        .lineLimit(1)
        .fixedSize()
    }

    private func chip(_ zone: Int) -> some View {
        let isOn = shown.contains(zone)
        let color = BrandColors.zone(zone)
        return Button {
            if isOn {
                if shown.count > 1 { shown.remove(zone) }
            } else {
                shown.insert(zone)
            }
        } label: {
            Text(ZoneText.short(zone))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isOn ? BrandColors.onAccent : BrandColors.dim)
                .frame(maxWidth: .infinity, minHeight: C.chipHeight)
                .background(isOn ? color : BrandColors.card, in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? color : BrandColors.line, lineWidth: C.chipBorder))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: isOn ? C.shownZone : C.hiddenZone, ZoneText.short(zone)))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func chart(_ trend: TrainerZoneTrend, index: Int, showsGoal: Bool) -> some View {
        let bands = T.bands(trend, zones: shown, mode: mode)
        let points = T.points(trend, zones: shown, mode: mode)
        let goal = showsGoal ? trend.goalThreshold.map { T.plotted($0, mode: mode) } : nil
        let domain = T.domain(bands: bands, points: points, goal: goal, mode: mode)
        let step = (domain.upperBound - domain.lowerBound) / 3
        let ticks = (0...3).map { domain.lowerBound + Double($0) * step }
        return Chart {
            ForEach(bands) { band in
                AreaMark(
                    x: .value(C.weekAxis, band.index), yStart: .value(C.valueAxis, band.low), yEnd: .value(C.valueAxis, band.high),
                    series: .value(C.valueAxis, "band-\(band.zone)")
                )
                .foregroundStyle(BrandColors.zone(band.zone).opacity(C.bandOpacity))
            }
            RuleMark(x: .value(C.weekAxis, index))
                .foregroundStyle(BrandColors.text.opacity(C.selectionOpacity))
                .lineStyle(StrokeStyle(lineWidth: 1))
            ForEach(points) { point in
                LineMark(x: .value(C.weekAxis, point.index), y: .value(C.valueAxis, point.value), series: .value(C.valueAxis, point.series))
                    .foregroundStyle(BrandColors.zone(point.zone))
                    .lineStyle(StrokeStyle(lineWidth: C.lineWidth, lineCap: .round, lineJoin: .round))
                if point.index == index {
                    PointMark(x: .value(C.weekAxis, point.index), y: .value(C.valueAxis, point.value))
                        .foregroundStyle(BrandColors.zone(point.zone))
                        .symbolSize(C.pointSize)
                }
            }
            if let goal {
                RuleMark(y: .value(C.valueAxis, goal))
                    .foregroundStyle(BrandColors.race)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: C.goalDash))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text(T.goalLine(abs(goal))).font(.caption2.weight(.semibold)).foregroundStyle(BrandColors.race)
                    }
            }
        }
        .chartXScale(domain: -0.3...(Double(trend.weeks.count - 1) + 0.3))
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .leading, values: ticks) { value in
                AxisGridLine().foregroundStyle(BrandColors.line)
                AxisValueLabel {
                    if let number = value.as(Double.self) { Text(T.axisLabel(number, mode: mode)).foregroundStyle(BrandColors.dim) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: T.monthStarts(trend)) { value in
                AxisValueLabel(anchor: .topLeading, collisionResolution: .disabled) {
                    if let position = value.as(Int.self), trend.weeks.indices.contains(position) {
                        Text(T.month(trend.weeks[position].start)).foregroundStyle(BrandColors.dim)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let frame = proxy.plotFrame else { return }
                        let x = location.x - geometry[frame].origin.x
                        guard let value: Double = proxy.value(atX: x) else { return }
                        selection = min(max(Int(value.rounded()), 0), trend.weeks.count - 1)
                    }
            }
        }
        .accessibilityLabel(T.weekLabel(trend.weeks[index]))
    }

    private func table(_ trend: TrainerZoneTrend, week: TrainerZoneWeek) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                ForEach(C.tableFonts.indices, id: \.self) { index in
                    grid(trend, week: week, font: C.tableFonts[index], spacing: index == 0 ? DSSpacing.s3 : DSSpacing.s2)
                }
            }
            Divider().overlay(BrandColors.line)
            VStack(alignment: .leading, spacing: DSSpacing.s1 + 2) {
                if !hasHeartRate { Text(C.noThreshold) }
                Text(C.averageNote)
                    + Text(C.greenWord).fontWeight(.semibold).foregroundStyle(BrandColors.accent)
                    + Text(C.insideNote)
                    + Text(C.yellowWord).fontWeight(.semibold).foregroundStyle(BrandColors.attention)
                    + Text(C.outsideNote)
                Text(C.tapNote)
            }
            .font(.caption)
            .foregroundStyle(BrandColors.dim)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, DSSpacing.s3)
        }
    }

    private func grid(_ trend: TrainerZoneTrend, week: TrainerZoneWeek, font: Font, spacing: CGFloat) -> some View {
        Grid(alignment: .leading, horizontalSpacing: spacing, verticalSpacing: 0) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                groupHeader(C.paceGroup).gridCellColumns(2)
                groupHeader(C.heartRateGroup).gridCellColumns(2)
            }
            GridRow {
                Text(C.zoneHeader)
                Text(C.targetHeader)
                Text(C.yourPaceHeader)
                Text(C.targetHeader)
                Text(C.yourHeartRateHeader)
            }
            .font(.caption)
            .foregroundStyle(BrandColors.dim)
            .padding(.vertical, DSSpacing.s2 - 2)
            ForEach(T.rows(trend, week: week)) { row in
                Divider().overlay(BrandColors.line).gridCellUnsizedAxes(.horizontal)
                GridRow(alignment: .firstTextBaseline) {
                    (Text(ZoneText.short(row.zone)).fontWeight(.bold).foregroundStyle(BrandColors.zone(row.zone))
                        + Text(" " + (C.names[row.zone] ?? "")).foregroundStyle(BrandColors.dim))
                    Text(row.paceTarget).foregroundStyle(BrandColors.dim)
                    value(row.pace, note: row.paceNote, has: row.hasPace)
                    Text(hasHeartRate ? row.heartRateTarget : C.empty).foregroundStyle(BrandColors.dim)
                    value(row.heartRate, note: row.heartRateNote, has: row.hasHeartRate)
                }
                .padding(.vertical, DSSpacing.s3)
            }
        }
        .font(font.monospacedDigit())
        .lineLimit(1)
        .fixedSize()
    }

    private func groupHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.s1) {
            Text(title).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(BrandColors.dim)
            Rectangle().fill(BrandColors.line).frame(height: 1)
        }
    }

    private func value(_ text: String, note: String?, has: Bool) -> some View {
        let color = !has ? BrandColors.dim : note == nil ? BrandColors.accent : BrandColors.attention
        var line = Text(text).fontWeight(.bold).foregroundStyle(color)
        if let note { line = line + Text(" " + note).font(.caption2).foregroundStyle(color) }
        return line
    }
}
