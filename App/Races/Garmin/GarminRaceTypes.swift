import Foundation
import GarminAPI

struct GarminRaceLink: Codable, Equatable, Sendable {
    let raceId: UUID
    var event: GarminRaceEvent
}

struct GarminRaceLinks: Codable, Equatable, Sendable {
    var imported: [Int64: GarminRaceLink] = [:]
    var declined: Set<Int64> = []
}

struct GarminRaceChange: Identifiable, Equatable, Sendable {
    let event: GarminRaceEvent
    let raceId: UUID
    let raceName: String
    let lines: [String]

    var id: Int64 { event.id }
}

struct GarminRaceSuggestions: Equatable, Sendable {
    var suggestions: [GarminRaceEvent] = []
    var changes: [GarminRaceChange] = []

    var isEmpty: Bool { suggestions.isEmpty && changes.isEmpty }
}

struct KnownRace: Equatable, Sendable {
    let id: UUID
    let name: String
    let day: String
    let startTime: String?
    let distance: Double
}
