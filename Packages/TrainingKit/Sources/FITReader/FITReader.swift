import Foundation
import FITSwiftSDK
import ZIPFoundation

public enum FITReader {
    public static func read(zip: Data) throws -> FITSummary {
        let archive: Archive
        do {
            archive = try Archive(data: zip, accessMode: .read)
        } catch {
            throw FITReaderError.invalidZip
        }
        guard let entry = archive.first(where: { $0.type == .file && $0.path.lowercased().hasSuffix(".fit") }) else {
            throw FITReaderError.noFitEntryInZip
        }
        var fit = Data()
        do {
            _ = try archive.extract(entry) { fit.append($0) }
        } catch {
            throw FITReaderError.invalidZip
        }
        return try read(fit: fit)
    }

    public static func read(fit: Data) throws -> FITSummary {
        let collector = MessageCollector()
        let decoder = Decoder(stream: InputStream(data: fit))
        decoder.addMesgListener(collector)
        do {
            guard try decoder.isFIT() else { throw FITReaderError.decodeFailed }
            try decoder.read()
        } catch {
            throw FITReaderError.decodeFailed
        }
        return FITSummary(
            samples: resample(collector.records),
            route: RouteSimplifier.simplify(route(from: collector.records), maxPoints: FITReaderConstants.maxRoutePoints),
            physio: physio(from: collector.physioMessages),
            structure: WorkoutStructureReader.structure(
                workouts: collector.workouts,
                steps: collector.steps,
                laps: collector.laps,
                origin: collector.records.lazy.compactMap { $0.getTimestamp()?.date.timeIntervalSince1970 }.first
            ),
            zoneInfo: collector.sessionTimeInZone.map(zoneInfo(from:))
        )
    }

    private static func resample(_ records: [RecordMesg]) -> [FITSample] {
        let timed = records.compactMap { record in record.getTimestamp().map { (record, $0.date.timeIntervalSince1970) } }
        guard let origin = timed.first?.1 else { return [] }
        let buckets = Dictionary(grouping: timed) { Int(($0.1 - origin) / FITReaderConstants.bucketSeconds) }
        return buckets.keys.sorted().map { key in
            let group = buckets[key]!.map(\.0)
            let heartRates = group.compactMap { $0.getHeartRate().map(Double.init) }
            let speeds = group.compactMap { $0.getEnhancedSpeed() ?? $0.getSpeed() }
            let altitudes = group.compactMap { $0.getEnhancedAltitude() ?? $0.getAltitude() }
            let distances = group.compactMap { $0.getDistance() }
            return FITSample(
                t: Double(key) * FITReaderConstants.bucketSeconds,
                heartRate: mean(heartRates).map { Int($0.rounded()) },
                speed: mean(speeds),
                altitude: mean(altitudes),
                distance: distances.last
            )
        }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private static func route(from records: [RecordMesg]) -> [Coordinate] {
        records.compactMap { record in
            guard let lat = record.getPositionLat(), let lon = record.getPositionLong() else { return nil }
            return Coordinate(
                lat: Double(lat) * FITReaderConstants.semicircleToDegrees,
                lon: Double(lon) * FITReaderConstants.semicircleToDegrees
            )
        }
    }

    private static func physio(from messages: [Mesg]) -> PhysioMetrics? {
        guard !messages.isEmpty else { return nil }
        var metrics = PhysioMetrics()
        for mesg in messages {
            if let raw = number(mesg.getFieldValue(fieldNum: FITReaderConstants.vo2maxField)), raw > 0 {
                metrics.vo2max = raw / FITReaderConstants.vo2maxDivisor * FITReaderConstants.vo2maxFactor
            }
            if let raw = number(mesg.getFieldValue(fieldNum: FITReaderConstants.recoveryMinutesField)) {
                metrics.recoveryMinutes = Int(raw)
            }
            if let raw = number(mesg.getFieldValue(fieldNum: FITReaderConstants.performanceConditionField)) {
                metrics.performanceCondition = Int(raw)
            }
        }
        return metrics
    }

    private static func zoneInfo(from mesg: TimeInZoneMesg) -> HeartRateZoneInfo {
        let boundaries = (mesg.getHrZoneHighBoundary() ?? []).prefix(FITReaderConstants.watchZoneFloorCount).map(heartRate)
        let floors = boundaries.compactMap { $0 }
        let calcType = mesg.getHrCalcType().flatMap { $0 == .invalid ? nil : Int($0.rawValue) }
        return HeartRateZoneInfo(
            thresholdHeartRate: heartRate(mesg.getThresholdHeartRate()),
            maxHeartRate: heartRate(mesg.getMaxHeartRate()),
            restingHeartRate: heartRate(mesg.getRestingHeartRate()),
            calcType: calcType,
            floors: floors.count == FITReaderConstants.watchZoneFloorCount ? floors : []
        )
    }

    private static func heartRate(_ value: UInt8?) -> Int? {
        guard let value, value > 0, value != FITReaderConstants.invalidHeartRate else { return nil }
        return Int(value)
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let v as Double: v
        case let v as Float: Double(v)
        case let v as Int8: Double(v)
        case let v as UInt8: Double(v)
        case let v as Int16: Double(v)
        case let v as UInt16: Double(v)
        case let v as Int32: Double(v)
        case let v as UInt32: Double(v)
        case let v as Int64: Double(v)
        case let v as UInt64: Double(v)
        case let v as Int: Double(v)
        default: nil
        }
    }
}

private final class MessageCollector: MesgListener {
    var records: [RecordMesg] = []
    var physioMessages: [Mesg] = []
    var workouts: [WorkoutMesg] = []
    var steps: [WorkoutStepMesg] = []
    var laps: [LapMesg] = []
    var sessionTimeInZone: TimeInZoneMesg?

    func onMesg(_ mesg: Mesg) {
        if mesg.mesgNum == Profile.MesgNum.record {
            records.append(RecordMesg(mesg: mesg))
        } else if mesg.mesgNum == Profile.MesgNum.workout {
            workouts.append(WorkoutMesg(mesg: mesg))
        } else if mesg.mesgNum == Profile.MesgNum.workoutStep {
            steps.append(WorkoutStepMesg(mesg: mesg))
        } else if mesg.mesgNum == Profile.MesgNum.lap {
            laps.append(LapMesg(mesg: mesg))
        } else if mesg.mesgNum == Profile.MesgNum.timeInZone {
            let timeInZone = TimeInZoneMesg(mesg: mesg)
            if sessionTimeInZone == nil, timeInZone.getReferenceMesg() == .session {
                sessionTimeInZone = timeInZone
            }
        } else if mesg.mesgNum == FITReaderConstants.physioMessageNumber {
            physioMessages.append(mesg)
        }
    }
}
