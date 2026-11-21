import FITReader
import Foundation
import SwiftUI
import Testing
import TrainingCore
import WorkoutAnalysis
@testable import trAIning

@MainActor
@Suite struct RecordSnapshotTests {
    private static let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
    private static let base = Date(timeIntervalSince1970: 1_790_000_000)

    private static func run(_ id: Int64, days: Double, five: Double, one: Double) -> RunEfforts {
        RunEfforts(activityId: id, start: base.addingTimeInterval(days * 86_400), efforts: [
            RunEffort(meters: 5_000, seconds: five, source: .wholeRun, startMeters: nil),
            RunEffort(meters: 1_000, seconds: one, source: .segment, startMeters: 3_000),
        ])
    }

    private static let runs = [
        run(1, days: 0, five: 1_510, one: 270),
        run(2, days: 70, five: 1_471, one: 262),
        run(3, days: 120, five: 1_445, one: 258),
        run(4, days: 160, five: 1_421, one: 252),
    ]

    private static var hits: [RecordHit] { PersonalRecords.timeline(runs)[4]?.records ?? [] }
    private static var fiveHit: [RecordHit] { hits.filter { $0.effort.meters == 5_000 } }
    private static var steps: [RecordStep] { PersonalRecords.progression(runs, meters: 5_000, through: 4) }

    private static func row(records: [RecordHit], goals: Int) -> WorkoutRowData {
        var data = WorkoutRowData(
            activityId: 4, title: "Ritmo 5 km", names: ["Ritmo 5 km"], dayIso: "2026-11-20", dateText: "sex., 20 de nov., 06:12",
            distanceText: "5,0 km", durationText: "23:41", paceText: "4:44 /km", hasPrescription: true, score: 92,
            kilometers: 5, zoneShares: [0, 0.1, 0.2, 0.7], weekStart: Day(iso: "2026-11-16")!
        )
        data.recordPill = RecordText.pill(records)
        data.goalPill = RecordText.goalPill(goals)
        return data
    }

    private static let route: [Coordinate] = (0...40).map { index in
        let angle = Double(index) / 40 * 2 * .pi
        return Coordinate(lat: -19.85 + 0.01 * sin(angle), lon: -43.97 + 0.01 * cos(angle))
    }

    private static func source() -> ShareSource {
        var input = WorkoutShareInput(
            title: "Ritmo 5 km", dateText: "20 nov", distanceMeters: 5_000, movingSeconds: 1_421,
            avgPaceSecondsPerKm: 284, avgHeartRate: 168, activePaceSecondsPerKm: nil, elevationGain: 12,
            route: Self.route,
            blocks: [], readingLine: nil
        )
        input.records = [ShareRecord(label: "5 km", seconds: 1_421, isWholeRun: true)]
        var source = ShareSource(input: input, track: [], zoneFloors: [100, 120, 140, 160, 175], series: [], seriesTitle: nil, seriesSummary: nil, evolution: [], feedbackLine: nil)
        source.recordHits = fiveHit
        source.recordSteps = steps
        source.recordActivityId = 4
        return source
    }

    private static func render(_ name: String, _ view: some View, width: CGFloat = 390, height: CGFloat? = nil) throws {
        guard let output else { return }
        let content = view
            .padding(16)
            .frame(width: width, height: height)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try image.pngData()?.write(to: output.appending(path: "\(name).png"))
    }

    private static func share(_ name: String, _ settings: ShareSettings) throws {
        guard let output else { return }
        let size = ShareStudioCard.size(settings)
        let renderer = ImageRenderer(content: ShareStudioCard(source: source(), settings: settings, progress: 1, photo: nil).environment(\.colorScheme, .dark))
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height > 0 ? size.height : nil)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try image.pngData()?.write(to: output.appending(path: "\(name).png"))
    }

    @Test func recordViewsRender() throws {
        #expect(Self.fiveHit.count == 1)
        #expect(Self.steps.count == 4)
        try Self.render("record-list", VStack(spacing: 12) {
            WorkoutRow(row: Self.row(records: Self.fiveHit, goals: 0))
            WorkoutRow(row: Self.row(records: Self.hits, goals: 2))
            WorkoutRow(row: Self.row(records: [], goals: 1))
        })
        try Self.render("record-detail-single", WorkoutRecordsCard(hits: Self.fiveHit, steps: Self.steps, activityId: 4))
        try Self.render("record-detail-multi", WorkoutRecordsCard(hits: Self.hits, steps: Self.steps, activityId: 4))
        let story = ShareSettings(format: .card, aspect: .story, coloring: .pace, hidesEnds: true, fields: ShareField.defaultEnabled.union([.record]))
        try Self.share("record-share-card", story)
        let record = ShareSettings(format: .record, aspect: .story, coloring: .pace, hidesEnds: true, fields: ShareField.defaultEnabled.union([.record]))
        try Self.share("record-share-format", record)
    }
}
