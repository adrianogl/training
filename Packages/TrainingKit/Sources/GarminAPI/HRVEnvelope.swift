struct HRVEnvelope: ListEnvelope {
    let hrvSummaries: [LossyElement<HRVSummaryDTO>]?
    var elements: [LossyElement<HRVSummaryDTO>] { hrvSummaries ?? [] }
}
