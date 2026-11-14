import CoreGraphics
import FITReader
import Foundation
import UIKit
import WorkoutAnalysis

enum ShareFormat: String, CaseIterable, Identifiable {
    case animatedRoute, animatedSquare, photo, series, evolution, sticker, card, blocks, strip

    var id: String { rawValue }
}

enum ShareAspect: String, CaseIterable, Identifiable {
    case story, portrait, square

    var id: String { rawValue }
}

enum RouteColoring: String, CaseIterable, Identifiable {
    case pace, zone, solid

    var id: String { rawValue }
}

struct TrackPoint: Equatable, Sendable {
    let coordinate: Coordinate
    let distance: Double
    let speed: Double?
    let heartRate: Int?
    let altitude: Double?
}

struct SeriesBar: Equatable, Sendable {
    let label: String
    let pace: Double
    let zone: Int?
    let inTarget: Bool
    let fastest: Double?
    let slowest: Double?
}

struct EvolutionPoint: Equatable, Sendable {
    let label: String
    let pace: Double
    let heartRate: Double?
    let isCurrent: Bool
}

struct ShareSource {
    let input: WorkoutShareInput
    let track: [TrackPoint]
    let zoneFloors: [Int]
    let series: [SeriesBar]
    let seriesTitle: String?
    let seriesSummary: String?
    let evolution: [EvolutionPoint]
    let feedbackLine: String?
}

struct ShareSettings: Equatable {
    var format: ShareFormat
    var aspect: ShareAspect
    var coloring: RouteColoring
    var hidesEnds: Bool
    var fields: Set<ShareField>
}
