protocol ListEnvelope<Element>: Decodable {
    associatedtype Element: Decodable
    var elements: [LossyElement<Element>] { get }
}
