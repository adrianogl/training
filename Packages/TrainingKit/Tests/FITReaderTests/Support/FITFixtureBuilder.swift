import Foundation
import FITSwiftSDK
import ZIPFoundation

enum FITFixtureBuilder {
    static let start: UInt32 = 1_100_000_000

    static func run(seconds: Int, msg140: [UInt8: Int]?, extra: [Mesg] = []) throws -> Data {
        let encoder = Encoder()
        let fileId = FileIdMesg()
        try fileId.setType(.activity)
        try fileId.setManufacturer(.garmin)
        encoder.write(mesg: fileId)

        for second in 0..<seconds {
            let record = RecordMesg()
            let angle = Double(second) / 40
            try record.setTimestamp(DateTime(timestamp: start + UInt32(second)))
            try record.setHeartRate(UInt8(120 + second % 40))
            try record.setEnhancedSpeed(3.0 + Double(second % 10) * 0.1)
            try record.setEnhancedAltitude(100 + Double(second % 20))
            try record.setDistance(Double(second) * 3)
            try record.setPositionLat(Int32(-300_000_000 + sin(angle) * 1_000_000))
            try record.setPositionLong(Int32(-550_000_000 + cos(angle * 1.3) * 1_000_000))
            encoder.write(mesg: record)
        }

        if let msg140 {
            let mesg = Mesg(name: "unknown", num: 140)
            for (fieldNum, value) in msg140 {
                switch fieldNum {
                case 17: try mesg.setFieldValue(fieldNum: fieldNum, value: Int8(value))
                case 9: try mesg.setFieldValue(fieldNum: fieldNum, value: UInt32(value))
                default: try mesg.setFieldValue(fieldNum: fieldNum, value: UInt32(value))
                }
            }
            encoder.write(mesg: mesg)
        }
        for mesg in extra {
            encoder.write(mesg: mesg)
        }
        return encoder.close()
    }

    static func workout(name: String, description: String?) throws -> WorkoutMesg {
        let mesg = WorkoutMesg()
        try mesg.setSport(.running)
        try mesg.setWktName(name)
        if let description {
            try mesg.setWktDescription(description)
        }
        return mesg
    }

    static func step(
        index: UInt16,
        intensity: Intensity = .active,
        meters: Double? = nil,
        seconds: Double? = nil,
        speed: (low: Double, high: Double)? = nil,
        heartRate: (low: UInt32, high: UInt32)? = nil,
        heartRateZone: UInt32? = nil
    ) throws -> WorkoutStepMesg {
        let mesg = WorkoutStepMesg()
        try mesg.setMessageIndex(index)
        try mesg.setIntensity(intensity)
        if let meters {
            try mesg.setDurationType(.distance)
            try mesg.setDurationDistance(meters)
        } else if let seconds {
            try mesg.setDurationType(.time)
            try mesg.setDurationTime(seconds)
        } else {
            try mesg.setDurationType(.open)
        }
        if let speed {
            try mesg.setTargetType(.speed)
            try mesg.setTargetValue(0)
            try mesg.setCustomTargetSpeedLow(speed.low)
            try mesg.setCustomTargetSpeedHigh(speed.high)
        } else if let heartRate {
            try mesg.setTargetType(.heartRate)
            try mesg.setTargetValue(0)
            try mesg.setCustomTargetHeartRateLow(heartRate.low)
            try mesg.setCustomTargetHeartRateHigh(heartRate.high)
        } else if let heartRateZone {
            try mesg.setTargetType(.heartRate)
            try mesg.setTargetHrZone(heartRateZone)
            try mesg.setCustomTargetValueLow(0)
            try mesg.setCustomTargetValueHigh(0)
        } else {
            try mesg.setTargetType(.open)
        }
        return mesg
    }

    static func repeatStep(index: UInt16, fromIndex: UInt32, count: UInt32) throws -> WorkoutStepMesg {
        let mesg = WorkoutStepMesg()
        try mesg.setMessageIndex(index)
        try mesg.setDurationType(.repeatUntilStepsCmplt)
        try mesg.setDurationValue(fromIndex)
        try mesg.setTargetValue(count)
        return mesg
    }

    static func lap(
        offset: UInt32,
        seconds: Double,
        meters: Double,
        stepIndex: UInt16?,
        intensity: Intensity = .active,
        trigger: LapTrigger = .distance,
        heartRate: (avg: UInt8, max: UInt8)? = nil
    ) throws -> LapMesg {
        let mesg = LapMesg()
        try mesg.setStartTime(DateTime(timestamp: start + offset))
        try mesg.setTimestamp(DateTime(timestamp: start + offset + UInt32(seconds)))
        try mesg.setTotalTimerTime(seconds)
        try mesg.setTotalDistance(meters)
        try mesg.setEnhancedAvgSpeed(meters / seconds)
        try mesg.setIntensity(intensity)
        try mesg.setLapTrigger(trigger)
        if let stepIndex {
            try mesg.setWktStepIndex(stepIndex)
        }
        if let heartRate {
            try mesg.setAvgHeartRate(heartRate.avg)
            try mesg.setMaxHeartRate(heartRate.max)
        }
        return mesg
    }

    static func timeInZone(
        reference: MesgNum,
        boundaries: [UInt8],
        threshold: UInt8,
        maxHeartRate: UInt8 = 190,
        restingHeartRate: UInt8 = 48,
        calcType: HrZoneCalc = .percentLthr
    ) throws -> TimeInZoneMesg {
        let mesg = TimeInZoneMesg()
        try mesg.setTimestamp(DateTime(timestamp: start))
        try mesg.setReferenceMesg(reference)
        try mesg.setReferenceIndex(0)
        for (index, value) in boundaries.enumerated() {
            try mesg.setHrZoneHighBoundary(index: index, value: value)
        }
        try mesg.setThresholdHeartRate(threshold)
        try mesg.setMaxHeartRate(maxHeartRate)
        try mesg.setRestingHeartRate(restingHeartRate)
        try mesg.setHrCalcType(calcType)
        return mesg
    }

    static func zip(containing fit: Data, entryName: String = "activity.fit") throws -> Data {
        let archive = try Archive(accessMode: .create)
        try archive.addEntry(with: entryName, type: .file, uncompressedSize: Int64(fit.count)) { position, size in
            fit.subdata(in: Int(position)..<Int(position) + size)
        }
        return archive.data ?? Data()
    }
}
