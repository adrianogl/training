extension KeyedDecodingContainer {
    func decodeRoundedInt(forKey key: Key) throws -> Int? {
        try decodeIfPresent(LenientInt.self, forKey: key)?.value
    }
}
