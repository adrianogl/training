import AVFoundation
import FITReader
import Foundation
import ImageIO
import Testing
import UIKit
import WorkoutAnalysis
@testable import trAIning

@MainActor @Suite struct ShareStudioTests {
    private static let route: [Coordinate] = (0...40).map { index in
        let angle = Double(index) / 40 * 2 * .pi
        return Coordinate(lat: -19.85 + 0.01 * sin(angle), lon: -43.97 + 0.01 * cos(angle))
    }

    private static let samples: [FITSample] = (0...400).map { index in
        FITSample(t: Double(index * 10), heartRate: 120 + index % 60, speed: index % 50 < 25 ? 4.4 : 3.0, altitude: 800 + Double(index % 30), distance: Double(index) * 15)
    }

    private static let input = WorkoutShareInput(
        title: "Intervalado", dateText: "13 nov", distanceMeters: 6_000, movingSeconds: 1_800,
        avgPaceSecondsPerKm: 300, avgHeartRate: 150, activePaceSecondsPerKm: 225, elevationGain: 30,
        route: route, blocks: [], readingLine: nil
    )

    private static func source() -> ShareSource {
        ShareSource(
            input: input,
            track: ShareTrackBuilder.track(route: route, samples: samples),
            zoneFloors: [100, 120, 140, 160, 175],
            series: [
                SeriesBar(label: "1º", pace: 226, zone: 4, inTarget: true, fastest: 211, slowest: 224),
                SeriesBar(label: "2º", pace: 230, zone: 5, inTarget: false, fastest: 211, slowest: 224),
            ],
            seriesTitle: "Série · 2 × 1000 m",
            seriesSummary: "alvo 3:31–3:44/km",
            evolution: [
                EvolutionPoint(label: "14 out", pace: 249, heartRate: 171, isCurrent: false),
                EvolutionPoint(label: "Este treino", pace: 241, heartRate: 168, isCurrent: true),
            ],
            feedbackLine: "Tiros estáveis"
        )
    }

    private static func settings(_ format: ShareFormat, aspect: ShareAspect = .story) -> ShareSettings {
        ShareSettings(format: format, aspect: aspect, coloring: .pace, hidesEnds: true, fields: ShareField.defaultEnabled)
    }

    @Test func trackMapsRouteToSampleValuesByDistance() {
        let track = ShareTrackBuilder.track(route: Self.route, samples: Self.samples)

        #expect(track.count == Self.route.count)
        #expect(track.first?.distance == 0)
        #expect(abs((track.last?.distance ?? 0) - 6_000) < 1)
        #expect(track.allSatisfy { $0.speed != nil && $0.heartRate != nil })
    }

    @Test func privacyTrimDropsFirstAndLastMeters() {
        let track = ShareTrackBuilder.track(route: Self.route, samples: Self.samples)

        let trimmed = ShareTrackBuilder.trimmed(track, hidesEnds: true)

        #expect((trimmed.first?.distance ?? 0) >= ShareStudioConstants.privacyTrimMeters)
        #expect((trimmed.last?.distance ?? 0) <= 6_000 - ShareStudioConstants.privacyTrimMeters)
        #expect(ShareTrackBuilder.trimmed(track, hidesEnds: false) == track)
    }

    @Test func paceAndZoneLevels() {
        let track = ShareTrackBuilder.track(route: Self.route, samples: Self.samples)

        let paces = ShareTrackBuilder.paceLevels(track)
        let zones = ShareTrackBuilder.zones(track, floors: [100, 120, 140, 160, 175])

        #expect(paces.allSatisfy { (0...1).contains($0) })
        #expect(paces.contains(1) && paces.contains(0))
        #expect(zones.allSatisfy { ($0 ?? 0) >= 2 && ($0 ?? 0) <= 4 })
    }

    @Test func seriesAndEvolutionComeFromBlocksAndComparison() {
        let block = WorkoutBlock(
            kind: .active, ordinal: 3, label: "Tiro 3",
            prescribed: PrescribedStep(index: 3, intensity: .active, duration: .distance(meters: 1_000), target: .speed(low: 1_000.0 / 224, high: 1_000.0 / 211)),
            laps: [], seconds: 217, distance: 1_000, avgSpeed: 1_000 / 217, avgHeartRate: 160, maxHeartRate: 170, dominantZone: 4, status: .inTarget
        )
        let rows = [
            ComparisonRow(activityId: 2, dateText: "Este treino", isCurrent: true, paceText: nil, heartRateText: nil, inTargetText: nil, secondsPerKilometer: 241, heartRate: 168),
            ComparisonRow(activityId: 1, dateText: "28 out", isCurrent: false, paceText: nil, heartRateText: nil, inTargetText: nil, secondsPerKilometer: 244, heartRate: 169),
        ]

        let bars = ShareSourceBuilder.seriesBars([block])
        let evolution = ShareSourceBuilder.evolution(rows)

        #expect(bars == [SeriesBar(label: "3º", pace: 217, zone: 4, inTarget: true, fastest: 211, slowest: 224)])
        #expect(evolution.map(\.label) == ["28 out", "Este treino"])
    }

    @Test func everyFormatRendersAnImage() {
        for format in ShareFormat.allCases {
            let image = ShareMediaExporter.image(source: Self.source(), settings: Self.settings(format), photo: nil, scale: 1)
            #expect((image?.size.width ?? 0) > 0, "formato \(format.rawValue)")
        }
        let square = ShareMediaExporter.image(source: Self.source(), settings: Self.settings(.animatedSquare, aspect: .square), photo: nil, scale: 1)
        #expect(square?.size == CGSize(width: 360, height: 360))
    }

    @Test func gifHasAllFramesAndLoops() async throws {
        let url = try await ShareMediaExporter.gif(source: Self.source(), settings: Self.settings(.animatedSquare, aspect: .square), photo: nil)

        let imageSource = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        #expect(CGImageSourceGetCount(imageSource) == ShareMediaExporter.frameProgresses(framesPerSecond: ShareStudioConstants.gifFramesPerSecond).count)
    }

    @Test func videoIsAnMP4WithTheAnimationLength() async throws {
        let url = try await ShareMediaExporter.video(source: Self.source(), settings: Self.settings(.animatedRoute), photo: nil)

        let duration = try await AVURLAsset(url: url).load(.duration).seconds
        #expect(abs(duration - (ShareStudioConstants.animationSeconds + ShareStudioConstants.holdSeconds)) < 0.2)
    }

    @Test func frameProgressesEaseAndHold() {
        let progresses = ShareMediaExporter.frameProgresses(framesPerSecond: 10)

        #expect(progresses.first == 0)
        #expect(progresses.suffix(Int(ShareStudioConstants.holdSeconds * 10)).allSatisfy { $0 == 1 })
        #expect(zip(progresses, progresses.dropFirst()).allSatisfy { $0 <= $1 })
    }
}
