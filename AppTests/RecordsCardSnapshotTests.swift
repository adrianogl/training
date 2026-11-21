import Foundation
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct RecordsCardSnapshotTests {
    @Test func rowsAlignTimesAndPaces() throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        func record(_ meters: Double, _ seconds: Double, days: Double, source: String) -> PersonalRecord {
            PersonalRecord(label: "", seconds: seconds, date: now.addingTimeInterval(-days * 86_400), source: source, meters: meters, activityId: nil)
        }
        let records = [
            record(1_000, 218, days: 400, source: "melhor trecho"), record(3_000, 674, days: 120, source: "melhor trecho"),
            record(5_000, 1_179, days: 300, source: "melhor trecho"), record(10_000, 2_433, days: 60, source: "corrida"),
            record(21_097.5, 5_310, days: 365, source: "melhor trecho"), record(42_195, 11_645, days: 3, source: "corrida"),
        ]
        let view = RecordsCard(records: records, now: now)
            .padding(16)
            .frame(width: 440)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try image.pngData()?.write(to: URL(filePath: dir).appending(path: "records-card.png"))
    }
}
