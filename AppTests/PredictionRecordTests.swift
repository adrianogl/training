import Foundation
import Insights
import SwiftUI
import Testing
@testable import trAIning

@Suite struct PredictionRecordTests {
    private func record(_ meters: Double, _ seconds: Double) -> PersonalRecord {
        PersonalRecord(label: "", seconds: seconds, date: .now, source: "", meters: meters, activityId: 1)
    }

    @Test func fasterThanTheRecordIsHighlighted() {
        let result = EvolutionText.recordComparison(predicted: 211, meters: 1_000, records: [record(1_000, 218)])
        #expect(result?.text == "★ 7 s abaixo do RP 3:38")
        #expect(result?.beats == true)
        let marathon = EvolutionText.recordComparison(predicted: 11_358, meters: 42_195, records: [record(42_195, 11_645)])
        #expect(marathon?.text == "★ 4:47 abaixo do RP 3:14:05")
    }

    @Test func slowerOrEqualIsPlain() {
        let slower = EvolutionText.recordComparison(predicted: 675, meters: 3_000, records: [record(3_000, 674)])
        #expect(slower?.text == "1 s acima do RP 11:14")
        #expect(slower?.beats == false)
        let equal = EvolutionText.recordComparison(predicted: 674, meters: 3_000, records: [record(3_000, 674)])
        #expect(equal?.text == "igual ao RP 11:14")
        #expect(equal?.beats == false)
    }

    @Test func withoutRecordSaysSo() {
        let none = EvolutionText.recordComparison(predicted: 675, meters: 3_000, records: [record(5_000, 1_179)])
        #expect(none?.text == "sem RP ainda")
        #expect(none?.beats == false)
    }

    @MainActor @Test func predictionCardsRender() throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] else { return }
        let values: [(MetricKind, Double, Double)] = [(.prediction1k, 211, -4), (.prediction3k, 675, -13), (.prediction5k, 1_161, -23), (.prediction10k, 2_397, -71), (.predictionHalf, 5_289, -156), (.predictionFull, 11_358, 6)]
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        var data: [MetricKind: MetricCardData] = [:]
        for (kind, value, change) in values {
            let points = (0..<20).map { ChartPoint(date: start.addingTimeInterval(Double($0) * 86_400 * 7), value: value - change * Double(19 - $0) / 19) }
            let chart = MetricChartData(kind: kind, daily: points, average: points, lastYear: [], projection: [], projectionBand: [], normalBand: nil, markers: [], raceDayPoint: nil, todayDate: start.addingTimeInterval(19 * 86_400 * 7))
            data[kind] = MetricCardData(kind: kind, stats: MetricStats(current: value, average: value, minimum: value, maximum: value - change, change: change), chart: chart)
        }
        let records = [record(1_000, 218), record(3_000, 674), record(5_000, 1_179), record(10_000, 2_433), record(21_097.5, 5_310), record(42_195, 11_645)]
        let group = MetricGroup(title: EvolutionConstants.predictionsGroupTitle, kinds: MetricKind.predictionKinds)
        let view = MetricGroupCard(group: group, data: data, records: records)
            .padding(16)
            .frame(width: 440)
            .background(BrandColors.background)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        try image.pngData()?.write(to: URL(filePath: dir).appending(path: "prediction-vs-record.png"))
    }
}
