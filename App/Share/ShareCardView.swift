import SwiftUI
import WorkoutAnalysis

struct ShareCardView: View {
    let content: ShareContent
    let template: ShareTemplate

    var body: some View {
        ShareFrame(template: template) {
            switch template {
            case .storiesDark, .transparent: story
            case .blocks: blocks
            case .strip: strip
            }
        }
    }

    private var isSticker: Bool { template.isSticker }
    private var labelColor: Color { isSticker ? BrandColors.stickerLabel : BrandColors.dim }
    private var distance: ShareValue? { content.values.first { $0.field == .distance } }
    private var otherValues: [ShareValue] { content.values.filter { $0.field != .distance } }

    private var story: some View {
        VStack(alignment: .leading, spacing: 0) {
            title.padding(.top, 14)
            if let route = content.route {
                ShareRouteView(
                    route: route,
                    color: isSticker ? .white : BrandColors.accent,
                    lineWidth: isSticker ? ShareConstants.stickerRouteLineWidth : ShareConstants.storyRouteLineWidth,
                    markerColor: isSticker ? BrandColors.accent : BrandColors.race
                )
                .padding(.vertical, ShareConstants.routeInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            if let distance {
                Text(distance.value)
                    .font(BrandFonts.number(ShareConstants.heroFontSize))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            statsGrid(otherValues, columns: ShareConstants.storyColumns, fontSize: ShareConstants.statFontSize)
                .padding(.top, 10)
            reading.padding(.top, 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(StickerShadow(isOn: isSticker))
    }

    private var blocks: some View {
        VStack(alignment: .leading, spacing: 0) {
            title.padding(.top, 12)
            if let bars = content.blockBars, !bars.isEmpty {
                HStack(alignment: .bottom, spacing: ShareConstants.barSpacing) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                        UnevenRoundedRectangle(
                            topLeadingRadius: ShareConstants.barCornerRadius,
                            topTrailingRadius: ShareConstants.barCornerRadius,
                            style: .continuous
                        )
                        .fill(BrandColors.zone(bar.zone))
                        .frame(maxWidth: .infinity)
                        .frame(height: ShareConstants.barsHeight * bar.height)
                    }
                }
                .frame(height: ShareConstants.barsHeight, alignment: .bottom)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            reading
            Spacer(minLength: 8)
            statsGrid(content.values, columns: ShareConstants.blocksColumns, fontSize: ShareConstants.blocksStatFontSize)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var strip: some View {
        HStack(alignment: .center, spacing: ShareConstants.stripSpacing) {
            if let route = content.route {
                ShareRouteView(route: route, color: .white, lineWidth: ShareConstants.stripRouteLineWidth, markerColor: nil)
                    .frame(width: ShareConstants.stripRouteSize, height: ShareConstants.stripRouteSize)
            }
            ForEach(content.values, id: \.field) { value in
                VStack(alignment: .leading, spacing: 2) {
                    Text(value.value)
                        .font(BrandFonts.number(ShareConstants.stripFontSize))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(value.label)
                        .font(.system(size: ShareConstants.stripLabelFontSize, weight: .medium))
                        .tracking(ShareConstants.statLabelTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(BrandColors.stickerLabel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(StickerShadow(isOn: true))
    }

    @ViewBuilder
    private var title: some View {
        if let text = content.title {
            Text(text)
                .font(.system(size: ShareConstants.titleFontSize))
                .foregroundStyle(labelColor)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var reading: some View {
        if let line = content.readingLine {
            Text(line)
                .font(.system(size: ShareConstants.readingFontSize))
                .foregroundStyle(isSticker ? .white : BrandColors.text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statsGrid(_ values: [ShareValue], columns: Int, fontSize: CGFloat) -> some View {
        let rows = stride(from: 0, to: values.count, by: columns).map { Array(values[$0..<min($0 + columns, values.count)]) }
        return Grid(alignment: .leading, horizontalSpacing: ShareConstants.statColumnSpacing, verticalSpacing: ShareConstants.statRowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(0..<columns, id: \.self) { index in
                        if index < row.count {
                            stat(row[index], fontSize: fontSize)
                        } else {
                            Color.clear.frame(height: 0)
                        }
                    }
                }
            }
        }
    }

    private func stat(_ value: ShareValue, fontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.value)
                .font(BrandFonts.number(fontSize))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(value.label)
                .font(.system(size: ShareConstants.statLabelFontSize, weight: .medium))
                .tracking(ShareConstants.statLabelTracking)
                .textCase(.uppercase)
                .foregroundStyle(labelColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
