import Foundation
import WorkoutAnalysis

enum RecordText {
    private typealias C = RecordTextConstants

    static func label(_ meters: Double) -> String {
        C.labels[meters] ?? WorkoutFormat.kilometers(meters) + " km"
    }

    static func inPhrase(_ meters: Double) -> String {
        C.inPhrases[meters] ?? String(format: C.inPhraseFallbackFormat, label(meters))
    }

    static func title(_ hit: RecordHit) -> String {
        let meters = hit.effort.meters
        if hit.isFirst { return C.firstTitles[meters] ?? label(meters) }
        return String(format: C.recordTitleFormat, inPhrase(meters))
    }

    static func gain(_ seconds: Double) -> String {
        seconds < C.minuteSeconds ? String(format: C.secondsFormat, Int(seconds.rounded())) : WorkoutFormat.clock(seconds)
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WorkoutFormat.locale
        formatter.dateFormat = C.dateFormat
        return formatter.string(from: date)
    }

    static func body(_ hit: RecordHit) -> String {
        let time = WorkoutFormat.clock(hit.effort.seconds)
        guard let previous = hit.previousSeconds, let gain = hit.gainSeconds else {
            return String(format: C.firstBodyFormat, time, inPhrase(hit.effort.meters))
        }
        let when = hit.previousStart.map(day) ?? ""
        if hit.effort.source == .segment {
            return String(format: C.segmentBodyFormat, label(hit.effort.meters).lowercased(), time, self.gain(gain), WorkoutFormat.clock(previous), when)
        }
        return String(format: C.wholeBodyFormat, time, self.gain(gain), WorkoutFormat.clock(previous), when)
    }

    static func near(_ near: RecordNear) -> String {
        String(format: C.nearBodyFormat, WorkoutFormat.clock(near.effort.seconds), inPhrase(near.effort.meters), gain(near.gapSeconds))
    }

    static func item(_ hit: RecordHit) -> String {
        let time = WorkoutFormat.clock(hit.effort.seconds)
        let name = label(hit.effort.meters).lowercased()
        guard let gain = hit.gainSeconds else { return String(format: C.listFirstFormat, name, time) }
        return String(format: C.listItemFormat, name, time, self.gain(gain))
    }

    static func counts(records: Int, goals: Int) -> String {
        var parts: [String] = []
        if records > 0 { parts.append(records == 1 ? C.recordOne : String(format: C.recordsFormat, records)) }
        if goals > 0 { parts.append(goals == 1 ? C.goalOne : String(format: C.goalsFormat, goals)) }
        return parts.joined(separator: C.countsJoin)
    }

    static func joined(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: C.listSeparator) + C.listLast + last
    }

    static func summary(records: [RecordHit], goals: [String]) -> String {
        var parts: [String] = []
        if !records.isEmpty {
            parts.append(String(format: records.count == 1 ? C.recordListSingleFormat : C.recordsListFormat, joined(records.map(item))))
        }
        if !goals.isEmpty {
            parts.append(String(format: goals.count == 1 ? C.goalListSingleFormat : C.goalsListFormat, joined(goals)))
        }
        return parts.joined(separator: " ")
    }

    static func pill(_ records: [RecordHit]) -> String? {
        guard let first = records.first else { return nil }
        let meters = first.effort.meters
        return records.count == 1 ? String(format: C.pillSingleFormat, C.pillLabels[meters] ?? label(meters)) : String(format: C.pillCountFormat, records.count)
    }

    static func goalPill(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? C.goalPillSingle : String(format: C.goalPillFormat, count)
    }
}

extension RecordText {
    static func source(_ effort: RunEffort) -> String {
        typealias K = RecordCardConstants
        guard effort.source == .segment else { return K.wholeRun }
        guard let start = effort.startMeters else { return K.segment }
        let first = Int(start / WorkoutConstants.metersPerKilometer) + 1
        let last = Int(((start + effort.meters) / WorkoutConstants.metersPerKilometer).rounded(.up))
        return first == last ? String(format: K.segmentKmFormat, first) : String(format: K.segmentRangeFormat, first, last)
    }

    static func detail(_ hit: RecordHit) -> String {
        typealias K = RecordCardConstants
        let gain = hit.gainSeconds.map { String(format: K.gainFormat, self.gain($0)) } ?? K.firstTime
        return gain + K.detailSeparator + source(hit.effort)
    }

    static func section(_ count: Int) -> String {
        count == 1 ? RecordCardConstants.sectionSingle : String(format: RecordCardConstants.sectionFormat, count)
    }
}
