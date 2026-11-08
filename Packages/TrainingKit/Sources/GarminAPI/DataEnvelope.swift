struct DataEnvelope<Element: Decodable>: ListEnvelope {
    let data: [LossyElement<Element>]?
    var elements: [LossyElement<Element>] { data ?? [] }
}
