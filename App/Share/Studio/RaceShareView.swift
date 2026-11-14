import SwiftUI
import WorkoutAnalysis

struct RaceShareCard: View {
    let summary: CompletedRaceSummary

    private typealias C = ShareStudioConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Logo(showsTagline: false)
            Text("\(C.racePrefix) \(summary.info.priority.rawValue) · \(summary.info.name)".uppercased())
                .font(.system(size: 12, weight: .semibold)).tracking(1.2)
                .foregroundStyle(BrandColors.race)
                .lineLimit(1)
            Text(summary.resultSeconds.map(WorkoutFormat.clock) ?? "—")
                .font(BrandFonts.number(64))
                .foregroundStyle(BrandColors.text)
            Text(comparison)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BrandColors.race)
            RaceSplitsChart(splits: summary.splits, goalPace: goalPace).frame(maxHeight: .infinity)
            if let halves {
                Text(halves).font(.system(size: 14)).foregroundStyle(BrandColors.text)
            }
        }
        .padding(24)
        .frame(width: C.width, height: C.heights[.story] ?? C.width, alignment: .topLeading)
        .background(ShareBackground())
        .environment(\.colorScheme, .dark)
    }

    private var goalPace: Double? {
        summary.goalSeconds.map { $0 / (summary.info.distance / WorkoutConstants.metersPerKilometer) }
    }

    private var comparison: String {
        [summary.resultVsGoalText.map { "\($0) \(C.raceVsGoal)" }, summary.resultVsEveText.map { "\($0) \(C.raceVsEve)" }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var halves: String? {
        let full = summary.splits.filter { $0.distance >= WorkoutConstants.metersPerKilometer * 0.99 }
        guard full.count >= 2 else { return nil }
        let half = full.count / 2
        let first = full.prefix(half).map(\.pace).reduce(0, +) / Double(half)
        let second = full.suffix(full.count - half).map(\.pace).reduce(0, +) / Double(full.count - half)
        return String(format: C.raceHalvesFormat, WorkoutFormat.clock(first), WorkoutFormat.clock(second))
    }
}

struct RaceSplitsChart: View {
    let splits: [RaceSplit]
    let goalPace: Double?

    var body: some View {
        Canvas { context, size in
            let paces = splits.map(\.pace) + [goalPace].compactMap { $0 }
            guard !splits.isEmpty, let fastest = paces.min(), let slowest = paces.max() else { return }
            let span = max(slowest - fastest, 10)
            let height = { (pace: Double) in size.height * (0.35 + 0.55 * (slowest - pace) / span) }
            let slot = size.width / Double(splits.count)
            for (index, split) in splits.enumerated() {
                let barHeight = height(split.pace)
                let rect = CGRect(x: slot * Double(index) + slot * 0.15, y: size.height - barHeight, width: slot * 0.7, height: barHeight)
                let slower = goalPace.map { split.pace > $0 } ?? false
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(slower ? BrandColors.attention : BrandColors.accentFill))
            }
            if let goalPace {
                let y = size.height - height(goalPace)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(BrandColors.dim), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .accessibilityHidden(true)
    }
}

struct RaceShareView: View {
    let summary: CompletedRaceSummary
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var exported: ExportedFile?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().frame(width: ShareStudioConstants.previewWidths[.story])
                        .clipShape(RoundedRectangle(cornerRadius: ShareConstants.previewCornerRadius, style: .continuous))
                }
                Button {
                    guard let data = image?.pngData() else { return }
                    let url = FileManager.default.temporaryDirectory.appending(path: ShareStudioConstants.imageFileName)
                    guard (try? data.write(to: url, options: .atomic)) != nil else { return }
                    exported = ExportedFile(url: url)
                } label: {
                    Text(ShareStudioConstants.shareImage)
                        .font(.system(size: ShareConstants.buttonFontSize, weight: .bold))
                        .foregroundStyle(BrandColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(ShareConstants.buttonPadding)
                        .background(BrandColors.accentFill, in: RoundedRectangle(cornerRadius: ShareConstants.buttonCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(BrandConstants.screenPadding)
            .background(BrandBackground())
            .navigationTitle(ShareStudioConstants.raceShareTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Pronto") { dismiss() }.tint(BrandColors.accent) }
            }
        }
        .task {
            let renderer = ImageRenderer(content: RaceShareCard(summary: summary))
            renderer.scale = ShareStudioConstants.imageScale
            renderer.isOpaque = true
            image = renderer.uiImage
        }
        .sheet(item: $exported) { file in
            ActivitySheet(items: [file.url]).presentationDetents([.medium, .large])
        }
    }
}
