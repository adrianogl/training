import FITReader
import Testing
@testable import WorkoutAnalysis

private func block(_ kind: BlockKind, speed: Double?, zone: Int?, prescribed: Bool = false) -> WorkoutBlock {
    WorkoutBlock(
        kind: kind,
        ordinal: 0,
        label: kind.rawValue,
        prescribed: prescribed ? PrescribedStep(index: 0, intensity: .active, duration: .open, target: .open) : nil,
        laps: [],
        seconds: 300,
        distance: (speed ?? 0) * 300,
        avgSpeed: speed,
        avgHeartRate: 150,
        maxHeartRate: 160,
        dominantZone: zone,
        status: .noTarget
    )
}

private func input(activePace: Double? = nil, route: [Coordinate]? = nil) -> WorkoutShareInput {
    WorkoutShareInput(
        title: "Intervalado 6 × 800 m",
        dateText: "3 nov",
        distanceMeters: 9_800,
        movingSeconds: 3_160,
        avgPaceSecondsPerKm: 322,
        avgHeartRate: 158,
        activePaceSecondsPerKm: activePace,
        elevationGain: 64,
        route: route ?? [Coordinate(lat: -23.5, lon: -46.6), Coordinate(lat: -23.51, lon: -46.61)],
        blocks: [
            block(.warmup, speed: 2.8, zone: 2),
            block(.active, speed: 4.3, zone: 5, prescribed: true),
            block(.recovery, speed: 2.0, zone: 1),
            block(.cooldown, speed: 2.7, zone: 2),
        ],
        readingLine: "5 de 6 tiros no pace previsto."
    )
}

@Suite struct ShareContentTests {
    @Test func defaultsLeaveElevationAndReadingOff() {
        #expect(ShareField.defaultEnabled == Set(ShareField.allCases).subtracting([.elevation, .readingLine]))
    }

    @Test func disabledFieldsAreOmitted() {
        let enabled = ShareField.defaultEnabled.subtracting([.title, .time, .avgHeartRate])
        let content = shareContent(record: input(activePace: 234), enabled: enabled, template: .storiesDark)
        #expect(content.title == nil)
        #expect(content.readingLine == nil)
        #expect(content.values.map(\.field) == [.distance, .avgPace, .activePace])
        #expect(content.values.map(\.value) == ["9,8 km", "5:22", "3:54"])

        let all = shareContent(record: input(activePace: 234), enabled: Set(ShareField.allCases), template: .storiesDark)
        #expect(all.title == "Intervalado 6 × 800 m · 3 nov")
        #expect(all.readingLine == "5 de 6 tiros no pace previsto.")
        #expect(all.values.map(\.value) == ["9,8 km", "52:40", "5:22", "158", "3:54", "+64 m"])
    }

    @Test func activePaceOnlyWithPrescription() {
        let free = shareContent(record: input(activePace: nil), enabled: ShareField.defaultEnabled, template: .storiesDark)
        #expect(!free.values.contains { $0.field == .activePace })

        let prescribed = shareContent(record: input(activePace: 234), enabled: ShareField.defaultEnabled, template: .storiesDark)
        #expect(prescribed.values.first { $0.field == .activePace } == ShareValue(field: .activePace, value: "3:54", label: "pace dos tiros"))
    }

    @Test func blocksTemplateHasBars() {
        let blocks = shareContent(record: input(), enabled: ShareField.defaultEnabled, template: .blocks)
        let bars = try! #require(blocks.blockBars)
        #expect(bars.map(\.kind) == [.warmup, .active, .recovery, .cooldown])
        #expect(bars.map(\.zone) == [2, 5, 1, 2])
        #expect(bars[1].height == 1)
        #expect(bars.allSatisfy { $0.height > 0 && $0.height <= 1 })
        #expect(bars[2].height < bars[0].height)
        #expect(blocks.values.map(\.label) == ["km", "tempo", "pace", "FC"])
        #expect(blocks.values.first == ShareValue(field: .distance, value: "9,8", label: "km"))

        for template in [ShareTemplate.storiesDark, .transparent, .strip] {
            #expect(shareContent(record: input(), enabled: ShareField.defaultEnabled, template: template).blockBars == nil)
        }
    }

    @Test func noRouteWhenToggledOff() {
        let on = shareContent(record: input(), enabled: ShareField.defaultEnabled, template: .transparent)
        #expect(on.route?.count == 2)

        let off = shareContent(record: input(), enabled: ShareField.defaultEnabled.subtracting([.route]), template: .transparent)
        #expect(off.route == nil)

        let empty = shareContent(record: input(route: []), enabled: ShareField.defaultEnabled, template: .storiesDark)
        #expect(empty.route == nil)
    }

    @Test func stripUsesShortLabels() {
        let strip = shareContent(record: input(activePace: 234), enabled: ShareField.defaultEnabled, template: .strip)
        #expect(strip.values.map(\.label) == ["distância", "tempo", "pace", "FC", "tiros"])
    }

    @Test func fieldSetRoundTrips() {
        let set: Set<ShareField> = [.route, .distance, .readingLine]
        #expect(ShareField.decode(ShareField.encode(set)) == set)
        #expect(ShareField.decode("") == [])
    }

    @Test func availableFieldsSkipMissingData() {
        var free = input(activePace: nil, route: [])
        free.elevationGain = nil
        free.readingLine = nil
        #expect(availableShareFields(free) == [.title, .distance, .time, .avgPace, .avgHeartRate])
        #expect(availableShareFields(input(activePace: 234)) == ShareField.allCases)
    }
}
