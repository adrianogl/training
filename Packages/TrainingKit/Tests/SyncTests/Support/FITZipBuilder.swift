import Foundation
import FITSwiftSDK
import ZIPFoundation

enum FITZipBuilder {
    static func run(seconds: Int) throws -> Data {
        let encoder = Encoder()
        let fileId = FileIdMesg()
        try fileId.setType(.activity)
        try fileId.setManufacturer(.garmin)
        encoder.write(mesg: fileId)

        let start: UInt32 = 1_100_000_000
        for second in 0..<seconds {
            let record = RecordMesg()
            try record.setTimestamp(DateTime(timestamp: start + UInt32(second)))
            try record.setHeartRate(UInt8(130 + second % 20))
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
        let fit = encoder.close()

        let archive = try Archive(accessMode: .create)
        try archive.addEntry(with: "activity.fit", type: .file, uncompressedSize: Int64(fit.count)) { position, size in
            fit.subdata(in: Int(position)..<Int(position) + size)
        }
        return archive.data ?? Data()
    }
}
