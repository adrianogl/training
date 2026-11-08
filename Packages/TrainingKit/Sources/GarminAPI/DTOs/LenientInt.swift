struct LenientInt: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let number = try decoder.singleValueContainer().decode(Double.self)
        guard number.isFinite, abs(number) < 9e18 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Número fora do intervalo"))
        }
        value = Int(number.rounded())
    }
}
