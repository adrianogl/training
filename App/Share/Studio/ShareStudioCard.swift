import SwiftUI
import WorkoutAnalysis

struct ShareStudioCard: View {
    let source: ShareSource
    let settings: ShareSettings
    let progress: Double
    var photo: UIImage?

    private typealias C = ShareStudioConstants

    var body: some View {
        switch settings.format {
        case .sticker: legacy(.transparent)
        case .card: legacy(.storiesDark)
        case .blocks: legacy(.blocks)
        case .strip: legacy(.strip)
        default: canvas.frame(width: C.width, height: C.heights[settings.aspect] ?? C.width).clipped().environment(\.colorScheme, .dark)
        }
    }

    static func size(_ settings: ShareSettings) -> CGSize {
        switch settings.format {
        case .sticker, .card: CGSize(width: ShareConstants.canvasWidth, height: ShareConstants.storiesHeight)
        case .blocks: CGSize(width: ShareConstants.canvasWidth, height: ShareConstants.blocksHeight)
        case .strip: CGSize(width: ShareConstants.canvasWidth, height: 0)
        default: CGSize(width: C.width, height: C.heights[settings.aspect] ?? C.width)
        }
    }

    static func isOpaque(_ settings: ShareSettings) -> Bool {
        switch settings.format {
        case .sticker, .strip: false
        default: true
        }
    }

    private func legacy(_ template: ShareTemplate) -> some View {
        var input = source.input
        input.route = track.map(\.coordinate)
        return ShareCardView(content: shareContent(record: input, enabled: settings.fields, template: template), template: template)
    }

    private var track: [TrackPoint] {
        ShareTrackBuilder.thinned(ShareTrackBuilder.trimmed(source.track, hidesEnds: settings.hidesEnds), limit: C.drawPointLimit)
    }

    @ViewBuilder
    private var canvas: some View {
        switch settings.format {
        case .animatedSquare: square
        case .photo: photoCard
        case .series: seriesCard
        case .evolution: evolutionCard
        default: story
        }
    }

    private var story: some View {
        VStack(alignment: .leading, spacing: 14) {
            Logo(showsTagline: false)
            if settings.fields.contains(.title) { title(color: BrandColors.text) }
            ShareTrackView(track: track, coloring: settings.coloring, zoneFloors: source.zoneFloors, progress: progress, lineWidth: 6)
                .frame(maxHeight: .infinity)
            stats(color: BrandColors.text, size: 30)
            if settings.aspect != .square {
                ShareElevationView(track: track, progress: progress).frame(height: 44)
            }
        }
        .padding(24)
        .background(ShareBackground())
    }

    private var square: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if settings.fields.contains(.title) { title(color: BrandColors.text) }
                Spacer(minLength: 0)
                AIIcon(size: 28)
            }
            ShareTrackView(track: track, coloring: settings.coloring, zoneFloors: source.zoneFloors, progress: progress, lineWidth: 7)
                .frame(maxHeight: .infinity)
            stats(color: BrandColors.text, size: 28)
        }
        .padding(22)
        .background(BrandColors.iconBase)
    }

    private var photoCard: some View {
        ZStack {
            Group {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Color(red: 0.14, green: 0.2, blue: 0.25), Color(red: 0.42, green: 0.36, blue: 0.26)], startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(width: C.width, height: C.heights[settings.aspect] ?? C.width)
            .clipped()
            VStack(alignment: .leading, spacing: 10) {
                stats(color: .white, size: 32)
                    .shadow(color: BrandColors.stickerShadow, radius: 3, y: 1)
                Spacer(minLength: 0)
                ShareTrackView(track: track, coloring: .solid, zoneFloors: [], progress: progress, lineWidth: 5, solidColor: .white, shadow: true)
                    .frame(height: (C.heights[settings.aspect] ?? C.width) * 0.38)
                Logo(showsTagline: false, showsIcon: false, fontSize: ShareConstants.stickerLogoFontSize)
                    .shadow(color: BrandColors.stickerShadow, radius: 3, y: 1)
            }
            .padding(24)
        }
    }

    private var seriesCard: some View {
        let bars = source.series
        let inTarget = bars.filter(\.inTarget).count
        return VStack(alignment: .leading, spacing: 12) {
            Logo(showsTagline: false)
            if let seriesTitle = source.seriesTitle {
                Text(seriesTitle.uppercased())
                    .font(.system(size: 12, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(BrandColors.dim)
            }
            Text(String(format: C.seriesInTargetFormat, inTarget, bars.count))
                .font(BrandFonts.number(40))
                .foregroundStyle(BrandColors.text)
            if let summary = source.seriesSummary {
                Text(summary).font(.system(size: 13)).foregroundStyle(BrandColors.dim)
            }
            ShareSeriesChart(bars: bars).frame(maxHeight: .infinity)
            if let line = source.feedbackLine {
                Text(line).font(.system(size: 14)).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .background(ShareBackground())
    }

    private var evolutionCard: some View {
        let points = source.evolution
        let first = points.first
        let last = points.last
        return VStack(alignment: .leading, spacing: 12) {
            Logo(showsTagline: false)
            Text(String(format: C.evolutionTitleFormat, points.count).uppercased())
                .font(.system(size: 12, weight: .semibold)).tracking(1.2)
                .foregroundStyle(BrandColors.dim)
            if let first, let last {
                let delta = Int((last.pace - first.pace).rounded())
                Text(String(format: delta <= 0 ? C.evolutionFasterFormat : C.evolutionSlowerFormat, abs(delta)))
                    .font(BrandFonts.number(44))
                    .foregroundStyle(delta <= 0 ? BrandColors.accent : BrandColors.attention)
                Text(evolutionSubtitle(first: first, last: last))
                    .font(.system(size: 13)).foregroundStyle(BrandColors.dim)
            }
            ShareEvolutionChart(points: points).frame(maxHeight: .infinity)
        }
        .padding(24)
        .background(ShareBackground())
    }

    private func evolutionSubtitle(first: EvolutionPoint, last: EvolutionPoint) -> String {
        var text = String(format: C.evolutionSubtitleFormat, first.label)
        if let before = first.heartRate, let now = last.heartRate, Int((now - before).rounded()) != 0 {
            let delta = Int((now - before).rounded())
            text += String(format: C.evolutionHeartFormat, abs(delta), delta < 0 ? C.lower : C.higher)
        }
        return text
    }

    private func title(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(source.input.title).font(.system(size: 17, weight: .bold)).foregroundStyle(color).lineLimit(1)
            Text(source.input.dateText).font(.system(size: 12)).foregroundStyle(color.opacity(0.7))
        }
    }

    private func stats(color: Color, size: CGFloat) -> some View {
        let values = statValues()
        return HStack(alignment: .top, spacing: 18) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.value).font(BrandFonts.number(size)).foregroundStyle(stat.highlight ? BrandColors.accent : color)
                    Text(stat.label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(color.opacity(0.7))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
    }

    private func statValues() -> [(value: String, label: String, highlight: Bool)] {
        let input = source.input
        let eased = progress
        var stats: [(String, String, Bool)] = []
        if settings.fields.contains(.distance), let meters = input.distanceMeters, meters > 0 {
            stats.append((WorkoutFormat.kilometers(meters * eased), C.distanceUnit, false))
        }
        if settings.fields.contains(.time), let seconds = input.movingSeconds, seconds > 0 {
            stats.append((WorkoutFormat.clock(seconds * eased), C.statLabels[.time] ?? "", false))
        }
        if settings.fields.contains(.activePace), let pace = input.activePaceSecondsPerKm, pace > 0 {
            stats.append((WorkoutFormat.clock(pace), C.statLabels[.activePace] ?? "", true))
        } else if settings.fields.contains(.avgPace), let pace = input.avgPaceSecondsPerKm, pace > 0 {
            stats.append((WorkoutFormat.clock(pace), C.statLabels[.avgPace] ?? "", true))
        }
        if stats.count < 3, settings.fields.contains(.avgHeartRate), let heartRate = input.avgHeartRate, heartRate > 0 {
            stats.append(("\(Int(heartRate.rounded()))", C.statLabels[.avgHeartRate] ?? "", false))
        }
        return stats.prefix(3).map { (value: $0.0, label: $0.1, highlight: $0.2) }
    }
}

struct ShareSeriesChart: View {
    let bars: [SeriesBar]

    var body: some View {
        Canvas { context, size in
            guard !bars.isEmpty else { return }
            let paces = bars.map(\.pace) + bars.compactMap(\.fastest) + bars.compactMap(\.slowest)
            guard let fastest = paces.min(), let slowest = paces.max() else { return }
            let low = fastest - 6
            let high = slowest + 6
            let y = { (pace: Double) in size.height * 0.08 + (pace - low) / (high - low) * size.height * 0.8 }
            if let top = bars.compactMap(\.fastest).min(), let bottom = bars.compactMap(\.slowest).max() {
                let band = CGRect(x: 0, y: y(top), width: size.width, height: y(bottom) - y(top))
                context.fill(Path(roundedRect: band, cornerRadius: 4), with: .color(BrandColors.accentFill.opacity(0.12)))
                context.stroke(Path(roundedRect: band, cornerRadius: 4), with: .color(BrandColors.accentFill.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            let slot = size.width / Double(bars.count)
            let width = min(slot * 0.66, 28)
            for (index, bar) in bars.enumerated() {
                let x = slot * (Double(index) + 0.5) - width / 2
                let top = y(bar.pace)
                let rect = CGRect(x: x, y: top, width: width, height: size.height * 0.9 - top)
                let color = bar.zone.map { BrandColors.zone($0).opacity(bar.inTarget ? 1 : 0.5) } ?? (bar.inTarget ? BrandColors.accentFill : BrandColors.attention)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(color))
                context.draw(
                    Text(bar.label).font(.system(size: 10)).foregroundStyle(BrandColors.dim),
                    at: CGPoint(x: x + width / 2, y: size.height * 0.96)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

struct ShareEvolutionChart: View {
    let points: [EvolutionPoint]

    var body: some View {
        Canvas { context, size in
            guard points.count >= 2, let fastest = points.map(\.pace).min(), let slowest = points.map(\.pace).max() else { return }
            let span = max(slowest - fastest, 6)
            let mid = (slowest + fastest) / 2
            let x = { (index: Int) in size.width * (Double(index) + 0.5) / Double(points.count) }
            let y = { (pace: Double) in size.height * 0.45 + (pace - mid) / span * size.height * 0.5 }
            var line = Path()
            for (index, point) in points.enumerated() {
                let position = CGPoint(x: x(index), y: y(point.pace))
                if index == 0 { line.move(to: position) } else { line.addLine(to: position) }
            }
            context.stroke(line, with: .color(BrandColors.accentFill), lineWidth: 2.5)
            for (index, point) in points.enumerated() {
                let center = CGPoint(x: x(index), y: y(point.pace))
                let radius: CGFloat = point.isCurrent ? 7 : 5
                let dot = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.fill(dot, with: .color(point.isCurrent ? BrandColors.accentFill : BrandColors.iconBase))
                context.stroke(dot, with: .color(BrandColors.accentFill), lineWidth: 2)
                context.draw(Text(WorkoutFormat.clock(point.pace)).font(BrandFonts.number(14)).foregroundStyle(BrandColors.text), at: CGPoint(x: center.x, y: center.y - 18))
                context.draw(Text(point.label).font(.system(size: 10)).foregroundStyle(BrandColors.dim), at: CGPoint(x: center.x, y: size.height * 0.88))
                if let heartRate = point.heartRate {
                    context.draw(Text("\(Int(heartRate.rounded())) bpm").font(.system(size: 10)).foregroundStyle(BrandColors.rest), at: CGPoint(x: center.x, y: size.height * 0.96))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
