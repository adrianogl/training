enum FITSampleCodingConstants {
    static let magic: [UInt8] = Array("FSB1".utf8)
    static let estimatedBytesPerSample = 39
    static let heartRate: UInt8 = 1 << 0
    static let speed: UInt8 = 1 << 1
    static let altitude: UInt8 = 1 << 2
    static let distance: UInt8 = 1 << 3
    static let cadence: UInt8 = 1 << 4
    static let stance: UInt8 = 1 << 5
    static let position: UInt8 = 1 << 6
}
