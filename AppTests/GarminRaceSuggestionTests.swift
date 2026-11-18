import Foundation
import GarminAPI
import SwiftUI
import Testing
@testable import trAIning

@MainActor
@Suite struct GarminRaceSuggestionTests {
    private let liveRun = GarminRaceEvent(id: 29_995_077, name: "Live! Run XP", day: "2026-11-22", startTime: "07:00", distanceMeters: 10_000, courseId: 514_884_211, url: nil)
    private let pampulha = GarminRaceEvent(id: 25_207_054, name: "27 Volta Internacional da Pampulha", day: "2026-12-06", startTime: "06:00", distanceMeters: 18_820, courseId: nil, url: nil)

    @Test func suggestsOnlyRacesThatAreNotInTheApp() {
        let existing = KnownRace(id: UUID(), name: "Live Run", day: "2026-11-22", startTime: nil, distance: 10_000)
        let state = GarminRaceSuggestionBuilder.build(events: [liveRun, pampulha], races: [existing], links: GarminRaceLinks())
        #expect(state.suggestions.map(\.id) == [pampulha.id])

        let other = KnownRace(id: UUID(), name: "Meia", day: "2026-11-22", startTime: nil, distance: 21_097.5)
        #expect(GarminRaceSuggestionBuilder.build(events: [liveRun], races: [other], links: GarminRaceLinks()).suggestions.count == 1)
    }

    @Test func declinedAndImportedEventsAreNotSuggestedAgain() {
        let raceId = UUID()
        var links = GarminRaceLinks()
        links.declined = [pampulha.id]
        links.imported[liveRun.id] = GarminRaceLink(raceId: raceId, event: liveRun)
        let state = GarminRaceSuggestionBuilder.build(events: [liveRun, pampulha], races: [], links: links)
        #expect(state.isEmpty)
    }

    @Test func changesInGarminAreListedForImportedRaces() {
        let raceId = UUID()
        var links = GarminRaceLinks()
        links.imported[liveRun.id] = GarminRaceLink(raceId: raceId, event: liveRun)
        let moved = GarminRaceEvent(id: liveRun.id, name: liveRun.name, day: "2026-11-29", startTime: "07:30", distanceMeters: 10_000, courseId: liveRun.courseId, url: nil)
        let race = KnownRace(id: raceId, name: "Live! Run XP", day: "2026-11-22", startTime: "07:00", distance: 10_000)
        let state = GarminRaceSuggestionBuilder.build(events: [moved], races: [race], links: links)
        #expect(state.suggestions.isEmpty)
        #expect(state.changes.first?.lines == ["data 22/11 → 29/11", "largada 07:00 → 07:30"])
    }

    @Test func linkStoreKeepsImportsAndDeclines() {
        let store = GarminRaceLinkStore(defaults: UserDefaults(suiteName: "garmin-races-\(UUID())")!)
        let raceId = UUID()
        store.recordImport(liveRun, raceId: raceId)
        store.decline(pampulha.id)
        #expect(store.load().imported[liveRun.id]?.raceId == raceId)
        #expect(store.load().declined == [pampulha.id])
    }

    @Test func suggestionCardRenders() throws {
        let output = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(filePath: $0, directoryHint: .isDirectory) }
        let card = GarminRaceSuggestionsCard(
            state: GarminRaceSuggestions(suggestions: [liveRun, pampulha]),
            onAdd: { _ in }, onIgnore: { _ in }, onApply: { _ in }, onKeep: { _ in }
        )
        for scheme in [ColorScheme.light, .dark] {
            let renderer = ImageRenderer(content: card.padding(16).frame(width: 390).background(BrandColors.background).environment(\.colorScheme, scheme))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            if let output, FileManager.default.fileExists(atPath: output.path()), let data = image.pngData() {
                try data.write(to: output.appending(path: "garmin-races-\(scheme).png"))
            }
        }
    }
}
