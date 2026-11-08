public enum FITReaderError: Error, Equatable {
    case noFitEntryInZip
    case invalidZip
    case decodeFailed
}
