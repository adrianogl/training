import Foundation
import FITSwiftSDK
import ZIPFoundation

enum FITZipBuilder {
    static let workoutName = "Intervalado sintético"
    private static let start: UInt32 = 1_100_000_000

    static func run(seconds: Int, withHeartRate: Bool = true) throws -> Data {
        try zip(try fit(seconds: seconds, extra: [], withHeartRate: withHeartRate))
    }

    static func structuredRun(seconds: Int) throws -> Data {
        try zip(try fit(seconds: seconds, extra: try workoutMesgs()))
    }

    private static func fit(seconds: Int, extra: [Mesg], withHeartRate: Bool = true) throws -> Data {
        let encoder = Encoder()
        let fileId = FileIdMesg()
        try fileId.setType(.activity)
        try fileId.setManufacturer(.garmin)
        encoder.write(mesg: fileId)

        for second in 0..<seconds {
            let record = RecordMesg()
            try record.setTimestamp(DateTime(timestamp: start + UInt32(second)))
            if withHeartRate {
                try record.setHeartRate(UInt8(130 + second % 20))
            }
            try record.setEnhancedSpeed(3.2)
            try record.setEnhancedAltitude(100)
            try record.setDistance(Double(second) * 3.2)
            try record.setPositionLat(Int32(-300_000_000 + second * 1_000))
            try record.setPositionLong(Int32(-550_000_000 + second * 1_000))
            encoder.write(mesg: record)
        }

        let physio = Mesg(name: "unknown", num: 140)
        try physio.setFieldValue(fieldNum: 7, value: UInt32(1_024_809))
        try physio.setFieldValue(fieldNum: 9, value: UInt32(1_440))
        try physio.setFieldValue(fieldNum: 17, value: Int8(3))
        encoder.write(mesg: physio)
        for mesg in extra {
            encoder.write(mesg: mesg)
        }
        return encoder.close()
    }

    private static func workoutMesgs() throws -> [Mesg] {
        let workout = WorkoutMesg()
        try workout.setSport(.running)
        try workout.setWktName(workoutName)

        let warmup = WorkoutStepMesg()
        try warmup.setMessageIndex(0)
        try warmup.setIntensity(.warmup)
        try warmup.setDurationType(.time)
        try warmup.setDurationTime(120)
        try warmup.setTargetType(.open)

        let interval = WorkoutStepMesg()
        try interval.setMessageIndex(1)
        try interval.setIntensity(.active)
        try interval.setDurationType(.distance)
        try interval.setDurationDistance(400)
        try interval.setTargetType(.speed)
        try interval.setTargetValue(0)
        try interval.setCustomTargetSpeedLow(3.5)
        try interval.setCustomTargetSpeedHigh(3.8)

        return [
            workout,
            warmup,
            interval,
            try lap(offset: 0, seconds: 120, meters: 384, stepIndex: 0, intensity: .warmup, trigger: .time),
            try lap(offset: 120, seconds: 125, meters: 400, stepIndex: 1, intensity: .active, trigger: .distance),
        ]
    }

    private static func lap(
        offset: UInt32,
        seconds: Double,
        meters: Double,
        stepIndex: UInt16,
        intensity: Intensity,
        trigger: LapTrigger
    ) throws -> LapMesg {
        let mesg = LapMesg()
        try mesg.setStartTime(DateTime(timestamp: start + offset))
        try mesg.setTimestamp(DateTime(timestamp: start + offset + UInt32(seconds)))
        try mesg.setTotalTimerTime(seconds)
        try mesg.setTotalDistance(meters)
        try mesg.setEnhancedAvgSpeed(meters / seconds)
        try mesg.setIntensity(intensity)
        try mesg.setLapTrigger(trigger)
        try mesg.setWktStepIndex(stepIndex)
        try mesg.setAvgHeartRate(145)
        try mesg.setMaxHeartRate(158)
        return mesg
    }

    private static func zip(_ fit: Data) throws -> Data {
        let archive = try Archive(accessMode: .create)
        try archive.addEntry(with: "activity.fit", type: .file, uncompressedSize: Int64(fit.count)) { position, size in
            fit.subdata(in: Int(position)..<Int(position) + size)
        }
        return archive.data ?? Data()
    }
}
