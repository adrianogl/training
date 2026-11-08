import Foundation
import FITSwiftSDK
import ZIPFoundation

enum FITFixtureBuilder {
    static func run(seconds: Int, msg140: [UInt8: Int]?) throws -> Data {
        let encoder = Encoder()
        let fileId = FileIdMesg()
        try fileId.setType(.activity)
        try fileId.setManufacturer(.garmin)
        encoder.write(mesg: fileId)

        let start: UInt32 = 1_100_000_000
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
        return encoder.close()
    }

    static func zip(containing fit: Data, entryName: String = "activity.fit") throws -> Data {
        let archive = try Archive(accessMode: .create)
        try archive.addEntry(with: entryName, type: .file, uncompressedSize: Int64(fit.count)) { position, size in
            fit.subdata(in: Int(position)..<Int(position) + size)
        }
        return archive.data ?? Data()
    }
}
