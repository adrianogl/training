import Security

struct KeychainError: Error, Equatable {
    let status: OSStatus
}
