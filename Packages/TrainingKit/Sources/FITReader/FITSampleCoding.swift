import Foundation

public enum FITSampleCoding {
    private typealias C = FITSampleCodingConstants

    public static func encode(_ samples: [FITSample]) -> Data {
        var data = Data(C.magic)
        data.reserveCapacity(C.magic.count + 4 + samples.count * C.estimatedBytesPerSample)
        append(UInt32(samples.count), to: &data)
        for sample in samples {
            var flags: UInt8 = 0
            if sample.heartRate != nil { flags |= C.heartRate }
            if sample.speed != nil { flags |= C.speed }
            if sample.altitude != nil { flags |= C.altitude }
            if sample.distance != nil { flags |= C.distance }
            if sample.cadence != nil { flags |= C.cadence }
            if sample.stanceTime != nil { flags |= C.stance }
            if sample.lat != nil, sample.lon != nil { flags |= C.position }
            data.append(flags)
            append(Float32(sample.t).bitPattern, to: &data)
            if let heartRate = sample.heartRate { append(UInt16(clamping: heartRate), to: &data) }
            for value in [sample.speed, sample.altitude, sample.distance, sample.cadence, sample.stanceTime].compactMap({ $0 }) {
                append(Float32(value).bitPattern, to: &data)
            }
            if let lat = sample.lat, let lon = sample.lon {
                append(lat.bitPattern, to: &data)
                append(lon.bitPattern, to: &data)
            }
        }
        return data
    }

    public static func decode(_ data: Data) -> [FITSample]? {
        guard data.starts(with: C.magic) else { return try? JSONDecoder().decode([FITSample].self, from: data) }
        var reader = Reader(bytes: [UInt8](data), offset: C.magic.count)
        guard let count = reader.read(UInt32.self) else { return nil }
        var samples: [FITSample] = []
        samples.reserveCapacity(Int(count))
        for _ in 0..<count {
            guard let flags = reader.read(UInt8.self), let t = reader.float() else { return nil }
            var sample = FITSample(t: t)
            if flags & C.heartRate != 0 { guard let value = reader.read(UInt16.self) else { return nil }; sample.heartRate = Int(value) }
            if flags & C.speed != 0 { guard let value = reader.float() else { return nil }; sample.speed = value }
            if flags & C.altitude != 0 { guard let value = reader.float() else { return nil }; sample.altitude = value }
            if flags & C.distance != 0 { guard let value = reader.float() else { return nil }; sample.distance = value }
            if flags & C.cadence != 0 { guard let value = reader.float() else { return nil }; sample.cadence = value }
            if flags & C.stance != 0 { guard let value = reader.float() else { return nil }; sample.stanceTime = value }
            if flags & C.position != 0 {
                guard let lat = reader.read(UInt64.self), let lon = reader.read(UInt64.self) else { return nil }
                sample.lat = Double(bitPattern: lat)
                sample.lon = Double(bitPattern: lon)
            }
            samples.append(sample)
        }
        return samples
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private struct Reader {
        let bytes: [UInt8]
        var offset: Int

        mutating func read<T: FixedWidthInteger>(_: T.Type) -> T? {
            let size = MemoryLayout<T>.size
            guard offset + size <= bytes.count else { return nil }
            var value: T = 0
            for index in 0..<size { value |= T(bytes[offset + index]) << (8 * index) }
            offset += size
            return T(littleEndian: value)
        }

        mutating func float() -> Double? {
            read(UInt32.self).map { Double(Float32(bitPattern: $0)) }
        }
    }
}
