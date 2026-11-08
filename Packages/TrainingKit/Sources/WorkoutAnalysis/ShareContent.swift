import FITReader
import Foundation

public func shareContent(record: WorkoutShareInput, enabled: Set<ShareField>, template: ShareTemplate) -> ShareContent {
    let available = Set(availableShareFields(record))
    let shown = enabled.intersection(available)
    let labels = template == .strip || template == .blocks ? ShareConstants.shortLabels : ShareConstants.fullLabels
    let values = ShareField.allCases.filter(shown.contains).compactMap { field -> ShareValue? in
        guard let value = shareValue(field, record: record, template: template), let label = labels[field] else { return nil }
        let isBareDistance = field == .distance && template == .blocks
        return ShareValue(field: field, value: value, label: isBareDistance ? ShareConstants.distanceUnit : label)
    }
    return ShareContent(
        title: shown.contains(.title) ? [record.title, record.dateText].filter { !$0.isEmpty }.joined(separator: ShareConstants.titleSeparator) : nil,
        values: values,
        route: shown.contains(.route) && template != .blocks ? record.route : nil,
        blockBars: template == .blocks ? shareBars(record.blocks) : nil,
        readingLine: shown.contains(.readingLine) ? record.readingLine : nil
    )
}

public func availableShareFields(_ record: WorkoutShareInput) -> [ShareField] {
    ShareField.allCases.filter { field in
        switch field {
        case .route: record.route.count >= ShareConstants.minimumRoutePoints
        case .title: true
        case .readingLine: record.readingLine?.isEmpty == false
        default: shareValue(field, record: record, template: .storiesDark) != nil
        }
    }
}

private func shareValue(_ field: ShareField, record: WorkoutShareInput, template: ShareTemplate) -> String? {
    switch field {
    case .distance:
        guard let meters = positive(record.distanceMeters) else { return nil }
        let kilometers = WorkoutFormat.kilometers(meters)
        return template == .blocks ? kilometers : "\(kilometers) \(ShareConstants.distanceUnit)"
    case .time:
        return positive(record.movingSeconds).map(WorkoutFormat.clock)
    case .avgPace:
        return positive(record.avgPaceSecondsPerKm).map(WorkoutFormat.clock)
    case .avgHeartRate:
        return positive(record.avgHeartRate).map { "\(Int($0.rounded()))" }
    case .activePace:
        return positive(record.activePaceSecondsPerKm).map(WorkoutFormat.clock)
    case .elevation:
        return positive(record.elevationGain).map { "+\(Int($0.rounded())) \(ShareConstants.elevationUnit)" }
    case .route, .title, .readingLine:
        return nil
    }
}

private func shareBars(_ blocks: [WorkoutBlock]) -> [BlockBar] {
    let speeds = blocks.compactMap { positive($0.avgSpeed) }
    guard let fastest = speeds.max(), let slowest = speeds.min() else {
        return blocks.map { BlockBar(kind: $0.kind, zone: $0.dominantZone, height: ShareConstants.minimumBarHeight) }
    }
    let span = fastest - slowest
    return blocks.map { block in
        guard let speed = positive(block.avgSpeed) else {
            return BlockBar(kind: block.kind, zone: block.dominantZone, height: ShareConstants.minimumBarHeight)
        }
        let share = span > 0 ? (speed - slowest) / span : 1
        let height = ShareConstants.minimumBarHeight + (1 - ShareConstants.minimumBarHeight) * share
        return BlockBar(kind: block.kind, zone: block.dominantZone, height: height)
    }
}

private func positive(_ value: Double?) -> Double? {
    guard let value, value.isFinite, value > 0 else { return nil }
    return value
}
